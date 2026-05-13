import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import type { PoolClient } from 'pg';

export type Migration = {
  filename: string;
  fullPath: string;
  checksum: string;
  sql: string;
  version: string;
};

type AppliedMigrationRecord = {
  version: string;
  filename: string | null;
  checksum: string | null;
};

const MIGRATIONS_TABLE = 'schema_migrations';
const MIGRATION_LOCK_KEYS = [8614, 1] as const;

const migrationsDirCandidates = [
  path.resolve(__dirname, '../../migrations'),
  path.resolve(process.cwd(), 'migrations'),
];

const resolveMigrationsDir = () => {
  for (const candidate of migrationsDirCandidates) {
    if (fs.existsSync(candidate) && fs.statSync(candidate).isDirectory()) {
      return candidate;
    }
  }

  throw new Error(`Could not locate migrations directory. Checked: ${migrationsDirCandidates.join(', ')}`);
};

export const loadMigrations = (): Migration[] => {
  const migrationsDir = resolveMigrationsDir();
  const filenames = fs
    .readdirSync(migrationsDir)
    .filter(filename => filename.endsWith('.sql'))
    .sort((left, right) => left.localeCompare(right));

  if (filenames.length === 0) {
    throw new Error(`No migration files were found in ${migrationsDir}`);
  }

  return filenames.map(filename => {
    const fullPath = path.join(migrationsDir, filename);
    const sql = fs.readFileSync(fullPath, 'utf8').trim();
    return {
      checksum: crypto.createHash('sha256').update(sql).digest('hex'),
      version: filename.replace(/\.sql$/i, ''),
      filename,
      fullPath,
      sql,
    };
  });
};

const ensureMigrationsTable = async (client: PoolClient) => {
  await client.query(`
    CREATE TABLE IF NOT EXISTS ${MIGRATIONS_TABLE} (
      version VARCHAR(255) PRIMARY KEY,
      applied_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    )
  `);

  await client.query(`
    ALTER TABLE ${MIGRATIONS_TABLE}
      ADD COLUMN IF NOT EXISTS filename VARCHAR(255)
  `);

  await client.query(`
    ALTER TABLE ${MIGRATIONS_TABLE}
      ADD COLUMN IF NOT EXISTS checksum VARCHAR(64)
  `);
};

const loadAppliedMigrations = async (client: PoolClient) => {
  await ensureMigrationsTable(client);

  const result = await client.query<AppliedMigrationRecord>(
    `
      SELECT version, filename, checksum
      FROM ${MIGRATIONS_TABLE}
      ORDER BY version ASC
    `
  );

  return new Map(result.rows.map(row => [row.version, row]));
};

export const applyPendingMigrations = async (client: PoolClient) => {
  await client.query('SELECT pg_advisory_lock($1, $2)', MIGRATION_LOCK_KEYS as unknown as number[]);

  try {
    const migrations = loadMigrations();
    const appliedMigrations = await loadAppliedMigrations(client);
    const pendingMigrations = migrations.filter(migration => !appliedMigrations.has(migration.version));

    for (const migration of migrations) {
      const appliedMigration = appliedMigrations.get(migration.version);

      if (!appliedMigration) {
        continue;
      }

      if (appliedMigration.checksum && appliedMigration.checksum !== migration.checksum) {
        throw new Error(
          `Migration ${migration.filename} was already applied with a different checksum. Reconcile the checked-in file and database state before continuing.`
        );
      }

      if (appliedMigration.filename === migration.filename && appliedMigration.checksum === migration.checksum) {
        continue;
      }

      await client.query(
        `
          UPDATE ${MIGRATIONS_TABLE}
          SET filename = $2,
              checksum = $3
          WHERE version = $1
        `,
        [migration.version, migration.filename, migration.checksum]
      );
    }

    for (const migration of pendingMigrations) {
      await client.query('BEGIN');

      try {
        await client.query(migration.sql);
        await client.query(
          `
            INSERT INTO ${MIGRATIONS_TABLE} (version, filename, checksum)
            VALUES ($1, $2, $3)
          `,
          [migration.version, migration.filename, migration.checksum]
        );
        await client.query('COMMIT');
      } catch (error) {
        await client.query('ROLLBACK');
        const message = error instanceof Error ? error.message : String(error);
        throw new Error(`Migration ${migration.filename} failed: ${message}`);
      }
    }

    return {
      latestVersion: migrations[migrations.length - 1]?.version ?? null,
      appliedVersions: pendingMigrations.map(migration => migration.version),
      pendingCount: pendingMigrations.length,
    };
  } finally {
    await client.query('SELECT pg_advisory_unlock($1, $2)', MIGRATION_LOCK_KEYS as unknown as number[]);
  }
};

export const verifyMigrationState = async (client: PoolClient) => {
  const migrations = loadMigrations();
  const appliedMigrations = await loadAppliedMigrations(client);
  const missingVersions = migrations
    .filter(migration => !appliedMigrations.has(migration.version))
    .map(migration => migration.version);

  if (missingVersions.length > 0) {
    throw new Error(
      `Database is missing applied migrations: ${missingVersions.join(', ')}. Run \`npm run db:migrate\` before starting the API in production.`
    );
  }

  const checksumMismatches = migrations
    .filter(migration => {
      const appliedMigration = appliedMigrations.get(migration.version);
      return appliedMigration?.checksum && appliedMigration.checksum !== migration.checksum;
    })
    .map(migration => migration.filename);

  if (checksumMismatches.length > 0) {
    throw new Error(
      `Database has checksum mismatches for migrations: ${checksumMismatches.join(', ')}. Re-run \`npm run db:migrate\` or reconcile the database state before starting the API.`
    );
  }

  const metadataGaps = migrations
    .filter(migration => {
      const appliedMigration = appliedMigrations.get(migration.version);
      return !appliedMigration?.filename || !appliedMigration?.checksum;
    })
    .map(migration => migration.filename);

  if (metadataGaps.length > 0) {
    throw new Error(
      `Database migration metadata is incomplete for: ${metadataGaps.join(', ')}. Run \`npm run db:migrate\` before starting the API in production.`
    );
  }

  return {
    latestVersion: migrations[migrations.length - 1]?.version ?? null,
    appliedCount: migrations.length,
  };
};
