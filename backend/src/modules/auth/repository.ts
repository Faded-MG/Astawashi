import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';

import type {
  AuthRepository,
  RefreshTokenRecord,
  ShopRecord,
  UserRecord,
} from './types.js';

export class PostgresAuthRepository implements AuthRepository {
  constructor(private readonly pool: Pool) {}

  async createShop(name: string): Promise<ShopRecord> {
    const result = await this.pool.query<ShopRecord>(
      `
        INSERT INTO shops (id, name)
        VALUES (gen_random_uuid(), $1)
        RETURNING id, name, created_at AS "createdAt"
      `,
      [name],
    );

    return result.rows[0]!;
  }

  async getUserByPhone(phone: string): Promise<UserRecord | null> {
    const result = await this.pool.query<UserRecord>(
      `
        SELECT id, phone, pin_hash AS "pinHash", shop_id AS "shopId", created_at AS "createdAt"
        FROM users
        WHERE phone = $1
      `,
      [phone],
    );

    return result.rows[0] ?? null;
  }

  async getUserById(id: string): Promise<UserRecord | null> {
    const result = await this.pool.query<UserRecord>(
      `
        SELECT id, phone, pin_hash AS "pinHash", shop_id AS "shopId", created_at AS "createdAt"
        FROM users
        WHERE id = $1
      `,
      [id],
    );

    return result.rows[0] ?? null;
  }

  async createUser(phone: string, pinHash: string, shopId: string): Promise<UserRecord> {
    const result = await this.pool.query<UserRecord>(
      `
        INSERT INTO users (id, phone, pin_hash, shop_id)
        VALUES (gen_random_uuid(), $1, $2, $3)
        RETURNING id, phone, pin_hash AS "pinHash", shop_id AS "shopId", created_at AS "createdAt"
      `,
      [phone, pinHash, shopId],
    );

    return result.rows[0]!;
  }

  async getRefreshTokenByHash(hash: string): Promise<RefreshTokenRecord | null> {
    const result = await this.pool.query<RefreshTokenRecord>(
      `
        SELECT id, user_id AS "userId", family_id AS "familyId", token_hash AS "tokenHash",
               revoked_at AS "revokedAt", replaced_by_token_id AS "replacedByTokenId",
               expires_at AS "expiresAt", created_at AS "createdAt"
        FROM refresh_tokens
        WHERE token_hash = $1
      `,
      [hash],
    );

    return result.rows[0] ?? null;
  }

  async createRefreshToken(data: {
    userId: string;
    familyId: string;
    tokenHash: string;
    expiresAt: Date;
  }): Promise<RefreshTokenRecord> {
    const result = await this.pool.query<RefreshTokenRecord>(
      `
        INSERT INTO refresh_tokens (id, user_id, family_id, token_hash, expires_at)
        VALUES ($1, $2, $3, $4, $5)
        RETURNING id, user_id AS "userId", family_id AS "familyId", token_hash AS "tokenHash",
                  revoked_at AS "revokedAt", replaced_by_token_id AS "replacedByTokenId",
                  expires_at AS "expiresAt", created_at AS "createdAt"
      `,
      [randomUUID(), data.userId, data.familyId, data.tokenHash, data.expiresAt],
    );

    return result.rows[0]!;
  }

  async markRefreshTokenReplaced(
    tokenId: string,
    replacementTokenId: string,
  ): Promise<void> {
    await this.pool.query(
      `
        UPDATE refresh_tokens
        SET replaced_by_token_id = $1,
            revoked_at = NOW(),
            rotated_at = NOW()
        WHERE id = $2
      `,
      [replacementTokenId, tokenId],
    );
  }
}
