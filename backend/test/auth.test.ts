import { randomUUID } from 'node:crypto';

import argon2 from 'argon2';
import { describe, expect, it } from 'vitest';

import { AuthError, AuthService } from '../src/modules/auth/service.js';
import type { AuthRepository, RefreshTokenRecord, ShopRecord, UserRecord } from '../src/modules/auth/types.js';

function encodeBase64Url(value: string): string {
  return Buffer.from(value).toString('base64url');
}

function createJwtSigner() {
  return {
    sign: (payload: Record<string, unknown>) => {
      const encodedHeader = encodeBase64Url(JSON.stringify({ alg: 'none', typ: 'JWT' }));
      const encodedPayload = encodeBase64Url(JSON.stringify(payload));
      return `${encodedHeader}.${encodedPayload}.signature`;
    },
    verify: (token: string) => {
      const payloadSegment = token.split('.')[1];
      if (!payloadSegment) {
        throw new Error('Invalid token');
      }
      return JSON.parse(Buffer.from(payloadSegment, 'base64url').toString('utf8')) as Record<string, unknown>;
    },
  };
}

function createInMemoryRepository(): AuthRepository {
  const shops = new Map<string, ShopRecord>();
  const users = new Map<string, UserRecord>();
  const refreshTokens = new Map<string, RefreshTokenRecord>();

  return {
    async createShop(name: string) {
      const shop: ShopRecord = {
        id: randomUUID(),
        name,
        createdAt: new Date().toISOString(),
      };
      shops.set(shop.id, shop);
      return shop;
    },
    async getUserByPhone(phone: string) {
      for (const user of users.values()) {
        if (user.phone === phone) {
          return user;
        }
      }
      return null;
    },
    async getUserById(id: string) {
      return users.get(id) ?? null;
    },
    async createUser(phone: string, pinHash: string, shopId: string) {
      const user: UserRecord = {
        id: randomUUID(),
        phone,
        pinHash,
        shopId,
        createdAt: new Date().toISOString(),
      };
      users.set(user.id, user);
      return user;
    },
    async getRefreshTokenByHash(hash: string) {
      for (const token of refreshTokens.values()) {
        if (token.tokenHash === hash) {
          return token;
        }
      }
      return null;
    },
    async createRefreshToken(data) {
      const record: RefreshTokenRecord = {
        id: randomUUID(),
        userId: data.userId,
        familyId: data.familyId,
        tokenHash: data.tokenHash,
        revokedAt: null,
        replacedByTokenId: null,
        expiresAt: data.expiresAt.toISOString(),
        createdAt: new Date().toISOString(),
      };
      refreshTokens.set(record.id, record);
      return record;
    },
    async markRefreshTokenReplaced(tokenId: string, replacementTokenId: string) {
      const record = refreshTokens.get(tokenId);
      if (!record) {
        return;
      }
      record.revokedAt = new Date().toISOString();
      record.replacedByTokenId = replacementTokenId;
    },
  };
}

describe('AuthService', () => {
  it('registers a shop and stores a hashed PIN', async () => {
    const repository = createInMemoryRepository();
    const signer = createJwtSigner();
    const service = new AuthService(
      repository,
      (payload) => signer.sign(payload),
      (token) => signer.verify(token) as {
        sub: string;
        shopId: string;
        familyId: string;
        jti: string;
        type: 'refresh';
      },
      900,
      2592000,
    );

    const session = await service.register({
      phone: '+251911223344',
      pin: '1234',
      shopName: 'Mekelle Corner',
    });

    const user = await repository.getUserByPhone('+251911223344');
    expect(user).not.toBeNull();
    expect(user?.pinHash).not.toBe('1234');
    await expect(argon2.verify(user!.pinHash, '1234')).resolves.toBe(true);
    expect(session.user.phone).toBe('+251911223344');
    expect(session.accessToken).toContain('.');
    expect(session.refreshToken).toContain('.');
  });

  it('logs in only with a valid PIN and rejects invalid credentials', async () => {
    const repository = createInMemoryRepository();
    const signer = createJwtSigner();
    const service = new AuthService(
      repository,
      (payload) => signer.sign(payload),
      (token) => signer.verify(token) as {
        sub: string;
        shopId: string;
        familyId: string;
        jti: string;
        type: 'refresh';
      },
      900,
      2592000,
    );

    const registered = await service.register({
      phone: '+251911223344',
      pin: '4321',
      shopName: 'Old Shop',
    });
    expect(registered.user.phone).toBe('+251911223344');

    await expect(service.login({ phone: '+251911223344', pin: '4321' })).resolves.toMatchObject({
      user: { phone: '+251911223344' },
    });

    await expect(service.login({ phone: '+251911223344', pin: 'wrong-pin' })).rejects.toBeInstanceOf(AuthError);
  });

  it('rotates refresh tokens and blocks replayed tokens', async () => {
    const repository = createInMemoryRepository();
    const signer = createJwtSigner();
    const service = new AuthService(
      repository,
      (payload) => signer.sign(payload),
      (token) => signer.verify(token) as {
        sub: string;
        shopId: string;
        familyId: string;
        jti: string;
        type: 'refresh';
      },
      900,
      2592000,
    );

    const firstSession = await service.register({
      phone: '+251922334455',
      pin: 'pass1234',
      shopName: 'Replay Shop',
    });

    const refreshed = await service.refresh({ refreshToken: firstSession.refreshToken });
    expect(refreshed.refreshToken).not.toBe(firstSession.refreshToken);
    expect(refreshed.user.id).toBe(firstSession.user.id);

    await expect(service.refresh({ refreshToken: firstSession.refreshToken })).rejects.toMatchObject({
      code: 'refresh_token_reused',
    });
  });
});
