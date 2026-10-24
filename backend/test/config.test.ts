import { afterEach, describe, expect, it, vi } from 'vitest';

const originalEnvironment = { ...process.env };

afterEach(() => {
  vi.resetModules();
  for (const key of Object.keys(process.env)) {
    if (!(key in originalEnvironment)) {
      delete process.env[key];
    }
  }
  Object.assign(process.env, originalEnvironment);
});

async function loadConfig() {
  return import('../src/config.js');
}

describe('backend configuration', () => {
  it('retains development defaults outside production', async () => {
    vi.stubEnv('NODE_ENV', 'development');
    delete process.env.JWT_SECRET;
    delete process.env.DATABASE_URL;

    const { config } = await loadConfig();

    expect(config.jwtSecret).toBe('astawash-dev-secret');
    expect(config.databaseUrl).toBe('postgresql://astawash:astawash@localhost:5432/astawash');
  });

  it('fails safely in production when JWT_SECRET is missing', async () => {
    vi.stubEnv('NODE_ENV', 'production');
    delete process.env.JWT_SECRET;
    vi.stubEnv('DATABASE_URL', 'postgresql://db.example/astawash');

    await expect(loadConfig()).rejects.toThrow(
      'JWT_SECRET must be configured with at least 32 characters in production.',
    );
  });

  it('fails safely in production when DATABASE_URL is missing', async () => {
    vi.stubEnv('NODE_ENV', 'production');
    vi.stubEnv('JWT_SECRET', 'a'.repeat(32));
    delete process.env.DATABASE_URL;

    await expect(loadConfig()).rejects.toThrow(
      'DATABASE_URL must be configured in production.',
    );
  });

  it.each([
    ['JWT_SECRET', ''],
    ['JWT_SECRET', ' '.repeat(32)],
    ['DATABASE_URL', ''],
    ['DATABASE_URL', '   '],
  ])('rejects empty or whitespace-only production %s', async (name, value) => {
    vi.stubEnv('NODE_ENV', 'production');
    vi.stubEnv('JWT_SECRET', 'a'.repeat(32));
    vi.stubEnv('DATABASE_URL', 'postgresql://db.example/astawash');
    vi.stubEnv(name, value);

    await expect(loadConfig()).rejects.toThrow(`${name} must be configured`);
  });

  it('accepts supplied production configuration', async () => {
    vi.stubEnv('NODE_ENV', 'production');
    vi.stubEnv('JWT_SECRET', 'a'.repeat(32));
    vi.stubEnv('DATABASE_URL', 'postgresql://db.example/astawash');

    const { config } = await loadConfig();

    expect(config.jwtSecret).toBe('a'.repeat(32));
    expect(config.databaseUrl).toBe('postgresql://db.example/astawash');
  });

  it('does not include supplied secret values in validation errors', async () => {
    const secret = 'private-marker';
    vi.stubEnv('NODE_ENV', 'production');
    vi.stubEnv('JWT_SECRET', secret);
    vi.stubEnv('DATABASE_URL', 'postgresql://db.example/astawash');

    const result = await loadConfig().catch((error: unknown) => error);

    if (!(result instanceof Error)) {
      throw new Error('Expected invalid production configuration to fail.');
    }
    expect(result.message).not.toContain(secret);
  });
});
