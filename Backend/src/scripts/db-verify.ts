import { verifyDbSchema } from '../config/db';
import { validateDatabaseConfig } from '../config/env';

const main = async () => {
  validateDatabaseConfig();
  await verifyDbSchema();
  console.log('Database schema verification completed successfully');
};

void main().catch(error => {
  console.error('Database schema verification failed:', error);
  process.exit(1);
});
