import { afterAll, describe, expect, it } from 'vitest';

import { buildServer } from '../src/server.js';

describe('GET /health', () => {
  const app = buildServer();

  afterAll(async () => {
    await app.close();
  });

  it('returns an ok status', async () => {
    const response = await app.inject({
      method: 'GET',
      url: '/health',
    });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({ status: 'ok' });
  });
});
