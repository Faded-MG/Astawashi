export interface AppConfig {
  jwtSecret: string;
  accessTokenTtlSeconds: number;
  refreshTokenTtlSeconds: number;
  databaseUrl: string;
  loginRateLimitMax: number;
  loginRateLimitWindowMs: number;
}

const production = process.env.NODE_ENV === 'production';
const jwtSecret =
  process.env.JWT_SECRET ?? (production ? undefined : 'astawash-dev-secret');
const databaseUrl =
  process.env.DATABASE_URL ??
  (production ? undefined : 'postgresql://astawash:astawash@localhost:5432/astawash');

if (!jwtSecret || (production && jwtSecret.length < 32)) {
  throw new Error('JWT_SECRET must be configured with at least 32 characters in production.');
}
if (!databaseUrl) {
  throw new Error('DATABASE_URL must be configured in production.');
}

function positiveInteger(name: string, fallback: number): number {
  const value = Number(process.env[name] ?? fallback);
  if (!Number.isSafeInteger(value) || value < 1) {
    throw new Error(`${name} must be a positive integer.`);
  }
  return value;
}

export const config: AppConfig = {
  jwtSecret,
  accessTokenTtlSeconds: positiveInteger('ACCESS_TOKEN_TTL_SECONDS', 900),
  refreshTokenTtlSeconds: positiveInteger('REFRESH_TOKEN_TTL_SECONDS', 2592000),
  databaseUrl,
  loginRateLimitMax: positiveInteger('LOGIN_RATE_LIMIT_MAX', 5),
  loginRateLimitWindowMs: positiveInteger('LOGIN_RATE_LIMIT_WINDOW_MS', 60000),
};
