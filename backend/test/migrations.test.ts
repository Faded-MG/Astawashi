import { spawnSync } from 'node:child_process';
import { describe, expect, it } from 'vitest';

describe('migration command target selection', () => {
  it('fails before starting the migration CLI when DATABASE_URL is missing', () => {
    const environment = { ...process.env };
    delete environment.DATABASE_URL;

    const result = spawnSync(process.execPath, ['scripts/migrate.js'], {
      cwd: process.cwd(),
      encoding: 'utf8',
      env: environment,
    });

    expect(result.status).toBe(1);
    expect(result.stderr).toContain('DATABASE_URL is required for migrations.');
  });

  it('rejects an empty or whitespace-only DATABASE_URL', () => {
    const result = spawnSync(process.execPath, ['scripts/migrate.js'], {
      cwd: process.cwd(),
      encoding: 'utf8',
      env: { ...process.env, DATABASE_URL: '   ' },
    });

    expect(result.status).toBe(1);
    expect(result.stderr).toContain('DATABASE_URL is required for migrations.');
  });

  it('allows the explicit local target without DATABASE_URL and does not connect for help', () => {
    const environment = { ...process.env };
    delete environment.DATABASE_URL;

    const result = spawnSync(
      process.execPath,
      ['scripts/migrate.js', '--local', '--help'],
      {
        cwd: process.cwd(),
        encoding: 'utf8',
        env: environment,
      },
    );

    expect(result.status).toBe(0);
    expect(result.stdout).toContain('node-pg-migrate');
  });
});
