import './env';
import { Pool, PoolClient } from 'pg';
import { applyPendingMigrations, verifyMigrationState } from './migrations';

const SYNC_TABLES = [
  'merchants',
  'staff',
  'products',
  'sales',
  'sale_line_items',
  'momo_transactions',
  'credit_entries',
] as const;

const REQUIRED_TRIGGER_NAMES = SYNC_TABLES.map(tableName => `update_${tableName}_updated_at`);

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

const formatMissingList = (values: readonly string[]) => values.join(', ');

const withClient = async <T>(callback: (client: PoolClient) => Promise<T>, existingClient?: PoolClient) => {
  if (existingClient) {
    return callback(existingClient);
  }

  const client = await pool.connect();

  try {
    return await callback(client);
  } finally {
    client.release();
  }
};

export const checkDbConnectivity = async (existingClient?: PoolClient) => {
  return withClient(async client => {
    const result = await client.query<{ ok: number }>('SELECT 1 AS ok');
    return result.rows[0]?.ok === 1;
  }, existingClient);
};

export const initDb = async () => {
  if (!process.env.DATABASE_URL) {
    throw new Error('DATABASE_URL is not set');
  }

  try {
    await withClient(async client => {
      const result = await applyPendingMigrations(client);
      if (result.pendingCount > 0) {
        console.log(`Applied database migrations: ${result.appliedVersions.join(', ')}`);
      } else {
        console.log('No pending database migrations were found');
      }

      await verifyDbSchema(client);
    });

    console.log('Database schema migration completed successfully');
  } catch (error) {
    console.error('Error initializing database:', error);
    throw error;
  }
};

export const verifyDbSchema = async (existingClient?: PoolClient) => {
  if (!process.env.DATABASE_URL) {
    throw new Error('DATABASE_URL is not set');
  }

  return withClient(async client => {
    const migrationState = await verifyMigrationState(client);

    const tableResult = await client.query<{ table_name: string }>(
      `
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_name = ANY($1::text[])
      `,
      [SYNC_TABLES]
    );

    const presentTables = new Set(tableResult.rows.map(row => row.table_name));
    const missingTables = SYNC_TABLES.filter(tableName => !presentTables.has(tableName));

    if (missingTables.length > 0) {
      throw new Error(
        `Database schema is missing required tables: ${formatMissingList(missingTables)}. Run \`npm run db:migrate\` before starting the API in production.`
      );
    }

    const columnResult = await client.query<{ table_name: string }>(
      `
        SELECT table_name
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = ANY($1::text[])
          AND column_name = 'server_updated_at'
      `,
      [SYNC_TABLES]
    );

    const presentCursorTables = new Set(columnResult.rows.map(row => row.table_name));
    const missingCursorColumns = SYNC_TABLES.filter(tableName => !presentCursorTables.has(tableName));

    if (missingCursorColumns.length > 0) {
      throw new Error(
        `Database schema is missing server_updated_at on: ${formatMissingList(missingCursorColumns)}. Run \`npm run db:migrate\` before starting the API in production.`
      );
    }

    const triggerResult = await client.query<{ event_object_table: string; trigger_name: string }>(
      `
        SELECT event_object_table, trigger_name
        FROM information_schema.triggers
        WHERE trigger_schema = 'public'
          AND event_object_table = ANY($1::text[])
          AND trigger_name = ANY($2::text[])
      `,
      [SYNC_TABLES, REQUIRED_TRIGGER_NAMES]
    );

    const triggerMap = new Map(triggerResult.rows.map(row => [row.event_object_table, row.trigger_name]));
    const missingTriggers = SYNC_TABLES.filter(
      tableName => triggerMap.get(tableName) !== `update_${tableName}_updated_at`
    );

    if (missingTriggers.length > 0) {
      throw new Error(
        `Database schema is missing updated_at triggers for: ${formatMissingList(missingTriggers)}. Run \`npm run db:migrate\` before starting the API in production.`
      );
    }

    console.log(
      `Database schema verification completed successfully at migration ${migrationState.latestVersion ?? 'unknown'}`
    );
  }, existingClient);
};

export const closeDbPool = async () => {
  await pool.end();
};

export default pool;
