export interface AppConfig {
  jwtSecret: string;
  accessTokenTtlSeconds: number;
  refreshTokenTtlSeconds: number;
  databaseUrl: string;
  loginRateLimitMax: number;
  loginRateLimitWindowMs: number;
}

export const config: AppConfig = {
  jwtSecret: process.env.JWT_SECRET ?? 'astawash-dev-secret',
  accessTokenTtlSeconds: Number(process.env.ACCESS_TOKEN_TTL_SECONDS ?? 900),
  refreshTokenTtlSeconds: Number(process.env.REFRESH_TOKEN_TTL_SECONDS ?? 2592000),
  databaseUrl:
    process.env.DATABASE_URL ?? 'postgresql://astawash:astawash@localhost:5432/astawash',
  loginRateLimitMax: Number(process.env.LOGIN_RATE_LIMIT_MAX ?? 5),
  loginRateLimitWindowMs: Number(process.env.LOGIN_RATE_LIMIT_WINDOW_MS ?? 60000),
};
