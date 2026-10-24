import 'dart:convert';
import 'dart:typed_data';

import 'package:astawash/core/sync/backend_api_client.dart';
import 'package:astawash/core/sync/sync_api.dart';
import 'package:astawash/core/sync/sync_models.dart';
import 'package:astawash/core/sync/token_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const shopId = '22222222-2222-4222-8222-222222222222';

  test(
    'login persists tokens/shop identity and uses the backend sync contract',
    () async {
      final store = FakeTokenStore();
      final adapter = RecordingAdapter((options) async {
        if (options.path == '/auth/login') {
          return _jsonResponse(
            200,
            _sessionJson(shopId, 'access-1', 'refresh-1'),
          );
        }
        if (options.path == '/sync/push') {
          return _jsonResponse(200, {
            'acceptedCustomerIds': ['customer-1'],
            'acceptedEntryIds': ['entry-1'],
            'alreadyAcceptedCustomerIds': [],
            'alreadyAcceptedEntryIds': [],
            'rejectedCustomers': [],
            'rejectedEntries': [],
          });
        }
        if (options.path == '/sync/pull') {
          return _jsonResponse(200, {
            'customers': [],
            'entries': [],
            'hasMore': false,
            'nextCursor': null,
          });
        }
        return _jsonResponse(404, {
          'error': {'code': 'not_found'},
        });
      });
      final api = BackendApiClient(
        baseUrl: 'https://api.example.test',
        tokenStore: store,
        dio: _dio(adapter),
      );

      expect(await api.login(phone: '+251911223344', pin: '1234'), shopId);
      expect(api.shopId, shopId);
      expect(
        store.tokens,
        isA<SessionTokens>()
            .having((tokens) => tokens.accessToken, 'accessToken', 'access-1')
            .having(
              (tokens) => tokens.refreshToken,
              'refreshToken',
              'refresh-1',
            )
            .having((tokens) => tokens.shopId, 'shopId', shopId),
      );

      final acknowledgements = await api.push(
        customers: const [],
        entries: const [],
      );
      final page = await api.pull(since: BigInt.from(42), limit: 50);

      expect(acknowledgements.acceptedCustomerIds, ['customer-1']);
      expect(page.hasMore, isFalse);
      expect(adapter.requests[1].headers['authorization'], 'Bearer access-1');
      expect(adapter.requests[1].data, {'customers': [], 'entries': []});
      expect(adapter.requests[2].queryParameters, {'since': '42', 'limit': 50});
      expect(adapter.requests[2].headers['authorization'], 'Bearer access-1');
    },
  );

  test(
    'refreshes an expired access token and retries the request once',
    () async {
      final store = FakeTokenStore()
        ..tokens = const SessionTokens(
          accessToken: 'expired-access',
          refreshToken: 'valid-refresh',
          shopId: shopId,
        );
      final adapter = RecordingAdapter((options) async {
        if (options.path == '/sync/pull' &&
            options.headers['authorization'] == 'Bearer expired-access') {
          return _jsonResponse(401, {
            'error': {'code': 'invalid_access_token', 'message': 'Expired.'},
          });
        }
        if (options.path == '/auth/refresh') {
          return _jsonResponse(
            200,
            _sessionJson(shopId, 'new-access', 'new-refresh'),
          );
        }
        if (options.path == '/sync/pull') {
          return _jsonResponse(200, {
            'customers': [],
            'entries': [],
            'hasMore': false,
            'nextCursor': null,
          });
        }
        return _jsonResponse(404, {});
      });
      final api = BackendApiClient(
        baseUrl: 'https://api.example.test',
        tokenStore: store,
        dio: _dio(adapter),
      );

      await api.pull(since: BigInt.zero, limit: 50);

      expect(adapter.requests.map((request) => request.path), [
        '/sync/pull',
        '/auth/refresh',
        '/sync/pull',
      ]);
      expect(adapter.requests[1].data, {'refreshToken': 'valid-refresh'});
      expect(
        adapter.requests.last.headers['authorization'],
        'Bearer new-access',
      );
      expect(store.tokens?.refreshToken, 'new-refresh');
      expect(api.shopId, shopId);
    },
  );

  test(
    'clears unusable credentials on refresh rejection without changing local data',
    () async {
      final store = FakeTokenStore()
        ..tokens = const SessionTokens(
          accessToken: 'expired-access',
          refreshToken: 'expired-refresh',
          shopId: shopId,
        );
      final adapter = RecordingAdapter((options) async {
        if (options.path == '/sync/pull') {
          return _jsonResponse(401, {
            'error': {'code': 'invalid_access_token', 'message': 'Expired.'},
          });
        }
        return _jsonResponse(401, {
          'error': {'code': 'invalid_refresh_token', 'message': 'Expired.'},
        });
      });
      final api = BackendApiClient(
        baseUrl: 'https://api.example.test',
        tokenStore: store,
        dio: _dio(adapter),
      );

      await expectLater(
        api.pull(since: BigInt.zero, limit: 50),
        throwsA(isA<AuthenticationRequiredException>()),
      );
      expect(store.tokens, isNull);
    },
  );

  test(
    'logout clears tokens and resets shopId and authentication state',
    () async {
      final store = FakeTokenStore()
        ..tokens = const SessionTokens(
          accessToken: 'access-1',
          refreshToken: 'refresh-1',
          shopId: shopId,
        )
        ..shopName = 'Test Shop';
      final api = await BackendApiClient.restore(
        baseUrl: 'https://api.example.test',
        tokenStore: store,
      );

      expect(api.isAuthenticated, isTrue);
      expect(api.shopId, shopId);

      await api.logout();

      expect(api.isAuthenticated, isFalse);
      expect(() => api.shopId, throwsStateError);
      expect(store.tokens, isNull);
      expect(store.shopName, isNull);
    },
  );
}

Dio _dio(RecordingAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'https://api.example.test'))
      ..httpClientAdapter = adapter;

ResponseBody _jsonResponse(int status, Object body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: const {
    'content-type': ['application/json'],
  },
);

Map<String, Object?> _sessionJson(
  String shopId,
  String accessToken,
  String refreshToken,
) => {
  'accessToken': accessToken,
  'refreshToken': refreshToken,
  'user': {'shopId': shopId},
};

class FakeTokenStore implements TokenStore {
  SessionTokens? tokens;
  String? shopName;

  @override
  Future<void> clear() async {
    tokens = null;
    shopName = null;
  }

  @override
  Future<SessionTokens?> read() async => tokens;

  @override
  Future<void> save(SessionTokens value) async {
    tokens = value;
  }

  @override
  Future<String?> readShopName() async => shopName;

  @override
  Future<void> saveShopName(String name) async {
    shopName = name;
  }
}

class RecordingAdapter implements HttpClientAdapter {
  RecordingAdapter(this.responseFor);

  final Future<ResponseBody> Function(RequestOptions options) responseFor;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return responseFor(options);
  }

  @override
  void close({bool force = false}) {}
}
