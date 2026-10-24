import { spawnSync } from 'node:child_process';

const localDatabaseUrl = 'postgresql://astawash:astawash@localhost:5432/astawash';
const localMode = process.argv[2] === '--local';
const databaseUrl = localMode ? localDatabaseUrl : process.env.DATABASE_URL;

if (typeof databaseUrl !== 'string' || databaseUrl.trim().length === 0) {
  console.error(
    'DATABASE_URL is required for migrations. Use "npm run migrate:local" for the local Compose database.',
  );
  process.exit(1);
}

const extraArgs = process.argv.slice(localMode ? 3 : 2);
const result = spawnSync(
  'node-pg-migrate',
  [
    'up',
    '--migrations-dir',
    'src/db/migrations',
    '--database-url',
    databaseUrl,
    ...extraArgs,
  ],
  { stdio: 'inherit' },
);

if (result.error) {
  console.error('Could not start the database migration command.');
  process.exit(1);
}

process.exit(result.status ?? 1);
