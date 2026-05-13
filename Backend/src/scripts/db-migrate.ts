import { initDb, verifyDbSchema } from '../config/db';
import { validateDatabaseConfig } from '../config/env';

const main = async () => {
  validateDatabaseConfig();
  await initDb();
  await verifyDbSchema();
  console.log('Database migration completed successfully');
};

void main().catch(error => {
  console.error('Database migration failed:', error);
  process.exit(1);
});
