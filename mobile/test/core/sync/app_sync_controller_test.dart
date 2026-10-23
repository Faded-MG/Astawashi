import 'dart:convert';
import 'dart:typed_data';

import 'package:astawash/core/db/app_database.dart';
import 'package:astawash/core/sync/app_sync_controller.dart';
import 'package:astawash/core/sync/backend_api_client.dart';
import 'package:astawash/core/sync/token_store.dart';
import 'package:astawash/core/sync/sync_models.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const shopId = '22222222-2222-4222-8222-222222222222';

  test('authenticates and exposes sync success state', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final tokenStore = _MemoryTokenStore();
    final apiClient = await BackendApiClient.restore(
      baseUrl: 'https://api.example.test',
      tokenStore: tokenStore,
      dio: Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..httpClientAdapter = _Adapter((request) async {
          if (request.path == '/auth/login') {
            return _jsonResponse(200, {
              'accessToken': 'access',
              'refreshToken': 'refresh',
              'user': {'shopId': shopId},
            });
          }
          if (request.path == '/sync/push') {
            return _jsonResponse(200, {
              'acceptedCustomerIds': [],
              'acceptedEntryIds': [],
              'alreadyAcceptedCustomerIds': [],
              'alreadyAcceptedEntryIds': [],
              'rejectedCustomers': [],
              'rejectedEntries': [],
            });
          }
          if (request.path == '/sync/pull') {
            return _jsonResponse(200, {
              'customers': [],
              'entries': [],
              'hasMore': false,
              'nextCursor': null,
            });
          }
          return _jsonResponse(404, {
            'error': {'code': 'not_found', 'message': 'Not found.'},
          });
        }),
    );
    final controller = AppSyncController(
      database: database,
      apiClient: apiClient,
    );
    addTearDown(controller.dispose);
    addTearDown(database.close);

    await controller.login(phone: '+251911223344', pin: '1234');
    expect(controller.isAuthenticated, isTrue);
    expect(tokenStore.tokens?.shopId, shopId);

    await controller.synchronize();
    expect(controller.status, AppSyncStatus.success);
    expect(controller.errorMessage, isNull);
    expect(controller.lastReport?.customersPushed, 0);
  });

  test(
    'shows a network failure while keeping local data unsynchronized',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final tokenStore = _MemoryTokenStore()
        ..tokens = const SessionTokens(
          accessToken: 'access',
          refreshToken: 'refresh',
          shopId: shopId,
        );
      final apiClient = await BackendApiClient.restore(
        baseUrl: 'https://api.example.test',
        tokenStore: tokenStore,
        dio: Dio(BaseOptions(baseUrl: 'https://api.example.test'))
          ..httpClientAdapter = _Adapter((request) async {
            throw DioException.connectionError(
              requestOptions: request,
              reason: 'Test network unavailable',
            );
          }),
      );
      final controller = AppSyncController(
        database: database,
        apiClient: apiClient,
      );
      addTearDown(controller.dispose);
      addTearDown(database.close);

      await database
          .into(database.customers)
          .insert(
            CustomersCompanion.insert(
              id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
              shopId: shopId,
              name: 'Offline Customer',
              createdAt: DateTime.utc(2026, 10, 23),
              updatedAt: DateTime.utc(2026, 10, 23),
            ),
          );

      await controller.synchronize();

      final customer =
          await (database.select(database.customers)..where(
                (row) => row.id.equals('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
              ))
              .getSingle();
      expect(controller.status, AppSyncStatus.failure);
      expect(controller.errorMessage, contains('Test network unavailable'));
      expect(customer.syncedAt, isNull);
    },
  );
}

class _MemoryTokenStore implements TokenStore {
  SessionTokens? tokens;

  @override
  Future<void> clear() async => tokens = null;

  @override
  Future<SessionTokens?> read() async => tokens;

  @override
  Future<void> save(SessionTokens value) async => tokens = value;
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);

  final Future<ResponseBody> Function(RequestOptions request) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(int status, Object body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}
