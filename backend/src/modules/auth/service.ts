import { createHash, randomBytes } from 'node:crypto';

import argon2 from 'argon2';
import { z } from 'zod';

import type { AuthRepository, AuthSession, RefreshTokenClaims, UserRecord } from './types.js';

export const registerSchema = z.object({
  phone: z.string().trim().min(7).max(20).regex(/^\+?[0-9]+$/),
  pin: z.string().min(4).max(32),
  shopName: z.string().trim().min(1).max(80).optional(),
});

export const loginSchema = z.object({
  phone: z.string().trim().min(7).max(20).regex(/^\+?[0-9]+$/),
  pin: z.string().min(4).max(32),
});

export const refreshSchema = z.object({
  refreshToken: z.string().min(20),
});

export class AuthService {
  constructor(
    private readonly repository: AuthRepository,
    private readonly signToken: (
      payload: Record<string, unknown>,
      options?: { expiresIn?: string | number },
    ) => string,
    private readonly verifyToken: (token: string) => RefreshTokenClaims,
    private readonly accessTokenTtlSeconds: number,
    private readonly refreshTokenTtlSeconds: number,
  ) {}

  async register(input: z.infer<typeof registerSchema>): Promise<AuthSession> {
    const { phone, pin, shopName } = registerSchema.parse(input);

    const existingUser = await this.repository.getUserByPhone(phone);
    if (existingUser) {
      throw new AuthError('phone_already_registered', 'This phone number is already registered.', 409);
    }

    const shop = await this.repository.createShop(shopName ?? 'Main Shop');
    const pinHash = await argon2.hash(pin);
    const user = await this.repository.createUser(phone, pinHash, shop.id);

    return this.createSession(user);
  }

  async login(input: z.infer<typeof loginSchema>): Promise<AuthSession> {
    const { phone, pin } = loginSchema.parse(input);

    const user = await this.repository.getUserByPhone(phone);
    if (!user) {
      throw new AuthError('invalid_credentials', 'Invalid phone number or PIN.', 401);
    }

    const passwordValid = await argon2.verify(user.pinHash, pin);
    if (!passwordValid) {
      throw new AuthError('invalid_credentials', 'Invalid phone number or PIN.', 401);
    }

    return this.createSession(user);
  }

  async refresh(input: z.infer<typeof refreshSchema>): Promise<AuthSession> {
    const { refreshToken } = refreshSchema.parse(input);

    let decoded: RefreshTokenClaims;
    try {
      decoded = this.verifyToken(refreshToken);
    } catch {
      throw new AuthError('invalid_refresh_token', 'Refresh token is invalid or expired.', 401);
    }

    if (decoded.type !== 'refresh') {
      throw new AuthError('invalid_refresh_token', 'Refresh token is invalid or expired.', 401);
    }

    const tokenHash = hashToken(refreshToken);
    const previousRecord = await this.repository.getRefreshTokenByHash(tokenHash);
    if (!previousRecord) {
      throw new AuthError('invalid_refresh_token', 'Refresh token is invalid or expired.', 401);
    }

    if (previousRecord.revokedAt || previousRecord.replacedByTokenId) {
      throw new AuthError('refresh_token_reused', 'Refresh token was already used.', 401);
    }

    if (previousRecord.userId !== decoded.sub || previousRecord.familyId !== decoded.familyId) {
      throw new AuthError('invalid_refresh_token', 'Refresh token does not match the session.', 401);
    }

    const user = await this.repository.getUserById(decoded.sub);
    if (!user) {
      throw new AuthError('user_not_found', 'User no longer exists.', 401);
    }

    const nextFamilyId = decoded.familyId;
    const nextRefreshToken = this.makeRefreshToken({
      userId: user.id,
      shopId: user.shopId,
      familyId: nextFamilyId,
      jti: randomBytes(18).toString('hex'),
    });
    const nextRefreshExpiresAt = new Date(Date.now() + this.refreshTokenTtlSeconds * 1000);
    const nextRefreshRecord = await this.repository.createRefreshToken({
      userId: user.id,
      familyId: nextFamilyId,
      tokenHash: hashToken(nextRefreshToken),
      expiresAt: nextRefreshExpiresAt,
    });

    await this.repository.markRefreshTokenReplaced(previousRecord.id, nextRefreshRecord.id);

    return {
      accessToken: this.signToken(
        {
          sub: user.id,
          shopId: user.shopId,
          type: 'access',
        },
        { expiresIn: `${this.accessTokenTtlSeconds}s` },
      ),
      refreshToken: nextRefreshToken,
      user: {
        id: user.id,
        phone: user.phone,
        shopId: user.shopId,
      },
    };
  }

  private async createSession(user: UserRecord): Promise<AuthSession> {
    const familyId = randomBytes(12).toString('hex');
    const refreshToken = this.makeRefreshToken({
      userId: user.id,
      shopId: user.shopId,
      familyId,
      jti: randomBytes(18).toString('hex'),
    });

    const refreshExpiresAt = new Date(Date.now() + this.refreshTokenTtlSeconds * 1000);
    await this.repository.createRefreshToken({
      userId: user.id,
      familyId,
      tokenHash: hashToken(refreshToken),
      expiresAt: refreshExpiresAt,
    });

    return {
      accessToken: this.signToken(
        {
          sub: user.id,
          shopId: user.shopId,
          type: 'access',
        },
        { expiresIn: `${this.accessTokenTtlSeconds}s` },
      ),
      refreshToken,
      user: {
        id: user.id,
        phone: user.phone,
        shopId: user.shopId,
      },
    };
  }

  private makeRefreshToken(data: {
    userId: string;
    shopId: string;
    familyId: string;
    jti: string;
  }): string {
    return this.signToken(
      {
        sub: data.userId,
        shopId: data.shopId,
        familyId: data.familyId,
        jti: data.jti,
        type: 'refresh',
      },
      { expiresIn: `${this.refreshTokenTtlSeconds}s` },
    );
  }
}

export class AuthError extends Error {
  constructor(
    public readonly code: string,
    message: string,
    public readonly statusCode: number,
  ) {
    super(message);
    this.name = 'AuthError';
  }
}

function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}
