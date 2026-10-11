import { Pool } from 'pg';

import { config } from '../config.js';

export const dbPool = new Pool({
  connectionString: config.databaseUrl,
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 3000,
});

export async function isDatabaseReachable(): Promise<boolean> {
  try {
    const result = await dbPool.query('SELECT 1 AS ok');
    return result.rows[0]?.ok === 1 || result.rows[0]?.ok === '1';
  } catch {
    return false;
  }
}

export async function closeDatabasePool(): Promise<void> {
  await dbPool.end();
}
