import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { buildServer } from '../src/server.js';

describe('sync routes', () => {
  const app = buildServer({ jwtSecret: 'sync-route-test-secret' });
  const userId = '11111111-1111-4111-8111-111111111111';
  const shopId = '22222222-2222-4222-8222-222222222222';
  let accessToken: string;

  beforeAll(async () => {
    await app.ready();
    accessToken = app.jwt.sign(
      { sub: userId, shopId, type: 'access' },
      { expiresIn: '1 minute' },
    );
  });

  afterAll(async () => {
    await app.close();
  });

  it.each([
    ['POST', '/sync/push', { customers: [], entries: [] }],
    ['GET', '/sync/pull?since=0', undefined],
  ] as const)('%s %s requires an access token', async (method, url, payload) => {
    const response = await app.inject({
      method,
      url,
      ...(payload === undefined ? {} : { payload }),
    });

    expect(response.statusCode).toBe(401);
    expect(response.json()).toMatchObject({
      error: { code: 'invalid_access_token' },
    });
  });

  it('returns a client validation error for malformed sync payloads', async () => {
    const response = await app.inject({
      method: 'POST',
      url: '/sync/push',
      headers: { authorization: `Bearer ${accessToken}` },
      payload: { customers: [{ id: 'not-a-uuid' }], entries: [] },
    });

    expect(response.statusCode).toBe(400);
    expect(response.json()).toMatchObject({
      error: { code: 'validation_error' },
    });
  });
});
