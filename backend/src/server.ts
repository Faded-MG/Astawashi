import Fastify, { type FastifyRequest } from 'fastify';
import rateLimit from '@fastify/rate-limit';
import jwt from '@fastify/jwt';

import { config } from './config.js';
import { dbPool, isDatabaseReachable } from './db/pool.js';
import { PostgresAuthRepository } from './modules/auth/repository.js';
import {
  AuthError,
  AuthService,
  loginSchema,
  refreshSchema,
  registerSchema,
} from './modules/auth/service.js';
import type { AuthRepository } from './modules/auth/types.js';
import { PostgresSyncRepository } from './modules/sync/repository.js';
import { SyncService, syncPullQuerySchema, syncPushRequestSchema } from './modules/sync/service.js';

export interface BuildServerOptions {
  authRepository?: AuthRepository;
  syncRepository?: PostgresSyncRepository;
  syncService?: SyncService;
  jwtSecret?: string;
  readinessCheck?: () => Promise<boolean>;
}

export function buildServer(options: BuildServerOptions = {}) {
  const app = Fastify({
    logger: false,
    ajv: {
      customOptions: {
        coerceTypes: true,
      },
    },
  });

  const jwtSecret = options.jwtSecret ?? config.jwtSecret;
  const repository = options.authRepository ?? new PostgresAuthRepository(dbPool);
  const authService = new AuthService(
    repository,
    (payload, options) => app.jwt.sign(payload, options),
    (token) => app.jwt.verify(token),
    config.accessTokenTtlSeconds,
    config.refreshTokenTtlSeconds,
  );
  const syncRepository = options.syncRepository ?? new PostgresSyncRepository(dbPool);
  const syncService = options.syncService ?? new SyncService(syncRepository);

  app.register(jwt, { secret: jwtSecret });
  app.register(rateLimit, {
    max: config.loginRateLimitMax,
    timeWindow: config.loginRateLimitWindowMs,
    keyGenerator: (request) =>
      (request.headers['x-forwarded-for'] as string | undefined) ??
      request.ip ??
      'unknown',
  });

  app.setErrorHandler((error, _request, reply) => {
    if (error instanceof AuthError) {
      return reply.code(error.statusCode).send({
        error: {
          code: error.code,
          message: error.message,
        },
      });
    }

    if (error instanceof Error && 'validation' in error) {
      return reply.code(400).send({
        error: {
          code: 'validation_error',
          message: 'Request validation failed.',
        },
      });
    }

    app.log.error(error);
    return reply.code(500).send({
      error: {
        code: 'internal_error',
        message: 'An unexpected server error occurred.',
      },
    });
  });

  app.get('/health', async () => ({ status: 'ok' }));

  app.get('/ready', async (_request, reply) => {
    const ready = await (options.readinessCheck ?? isDatabaseReachable)();
    if (!ready) {
      return reply.code(503).send({
        status: 'not_ready',
        database: 'unreachable',
      });
    }

    return { status: 'ok', database: 'connected' };
  });

  app.post(
    '/auth/register',
    { config: { rateLimit: { max: 3, timeWindow: '1 minute' } } },
    async (request, reply) => {
      const payload = registerSchema.parse(request.body);
      const session = await authService.register(payload);
      return reply.code(201).send(session);
    },
  );

  app.post(
    '/auth/login',
    { config: { rateLimit: { max: 5, timeWindow: '1 minute' } } },
    async (request, reply) => {
      const payload = loginSchema.parse(request.body);
      const session = await authService.login(payload);
      return reply.code(200).send(session);
    },
  );

  app.post(
    '/auth/refresh',
    { config: { rateLimit: { max: 10, timeWindow: '1 minute' } } },
    async (request, reply) => {
      const payload = refreshSchema.parse(request.body);
      const session = await authService.refresh(payload);
      return reply.code(200).send(session);
    },
  );

  app.get('/auth/me', async (request, reply) => {
    const claims = await verifyAccessToken(request);
    return reply.code(200).send({
      id: claims.sub,
      shopId: claims.shopId,
      type: claims.type,
    });
  });

  // Sync enforcement is JWT-derived: the server trusts the authenticated shop ID,
  // never a client-supplied shop identifier.
  app.post('/sync/push', async (request, reply) => {
    const claims = await verifyAccessToken(request);
    const payload = syncPushRequestSchema.parse(request.body);
    const result = await syncService.push(claims.shopId, payload);
    return reply.code(200).send(result);
  });

  app.get('/sync/pull', async (request, reply) => {
    const claims = await verifyAccessToken(request);
    const query = syncPullQuerySchema.parse(request.query);
    const page = await syncService.pull(claims.shopId, query);
    return reply.code(200).send(page);
  });

  return app;
}

async function verifyAccessToken(request: FastifyRequest) {
  try {
    const claims = await request.jwtVerify<{
      sub: string;
      shopId: string;
      type: 'access';
    }>();
    if (claims.type !== 'access') {
      throw new Error('Invalid token type');
    }
    return claims;
  } catch {
    throw new AuthError('invalid_access_token', 'Access token is missing or invalid.', 401);
  }
}
