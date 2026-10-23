export interface ShopRecord {
  id: string;
  name: string;
  createdAt: string;
}

export interface UserRecord {
  id: string;
  phone: string;
  pinHash: string;
  shopId: string;
  createdAt: string;
}

export interface RefreshTokenRecord {
  id: string;
  userId: string;
  familyId: string;
  tokenHash: string;
  revokedAt: string | null;
  replacedByTokenId: string | null;
  expiresAt: string;
  createdAt: string;
}

export interface AuthRepository {
  createShop(name: string): Promise<ShopRecord>;
  getUserByPhone(phone: string): Promise<UserRecord | null>;
  getUserById(id: string): Promise<UserRecord | null>;
  createUser(phone: string, pinHash: string, shopId: string): Promise<UserRecord>;
  getRefreshTokenByHash(hash: string): Promise<RefreshTokenRecord | null>;
  createRefreshToken(data: {
    userId: string;
    familyId: string;
    tokenHash: string;
    expiresAt: Date;
  }): Promise<RefreshTokenRecord>;
  markRefreshTokenReplaced(tokenId: string, replacementTokenId: string): Promise<void>;
}

export interface AuthSession {
  accessToken: string;
  refreshToken: string;
  user: {
    id: string;
    phone: string;
    shopId: string;
  };
}

export interface AccessTokenClaims {
  sub: string;
  shopId: string;
  type: 'access';
  iat: number;
  exp: number;
}

export interface RefreshTokenClaims {
  sub: string;
  shopId: string;
  familyId: string;
  jti: string;
  type: 'refresh';
  iat: number;
  exp: number;
}
