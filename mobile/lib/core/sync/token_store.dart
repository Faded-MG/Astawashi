import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'sync_models.dart';

abstract interface class TokenStore {
  Future<SessionTokens?> read();
  Future<void> save(SessionTokens tokens);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _accessTokenKey = 'astawash.access_token';
  static const _refreshTokenKey = 'astawash.refresh_token';
  static const _shopIdKey = 'astawash.shop_id';

  final FlutterSecureStorage _storage;

  @override
  Future<SessionTokens?> read() async {
    final accessToken = await _storage.read(key: _accessTokenKey);
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    final shopId = await _storage.read(key: _shopIdKey);
    if (accessToken == null || refreshToken == null || shopId == null) {
      return null;
    }
    return SessionTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      shopId: shopId,
    );
  }

  @override
  Future<void> save(SessionTokens tokens) async {
    await _storage.write(key: _accessTokenKey, value: tokens.accessToken);
    await _storage.write(key: _refreshTokenKey, value: tokens.refreshToken);
    await _storage.write(key: _shopIdKey, value: tokens.shopId);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _shopIdKey);
  }
}
