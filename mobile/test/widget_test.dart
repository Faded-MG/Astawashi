import 'dart:convert';

import 'package:astawash/app/providers/app_providers.dart';
import 'package:astawash/app/router/app_router.dart';
import 'package:astawash/core/db/app_database.dart';
import 'package:astawash/core/sync/backend_api_client.dart';
import 'package:astawash/core/sync/sync_models.dart';
import 'package:astawash/core/sync/token_store.dart';
import 'package:astawash/main.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const shopId = '22222222-2222-4222-8222-222222222222';

  testWidgets('signs in and manually triggers sync from the app', (
    WidgetTester tester,
  ) async {
    final router = createAppRouter(initialLocation: '/signin');
    final database = AppDatabase(NativeDatabase.memory());
    final tokenStore = _MemoryTokenStore();
    final apiClient = BackendApiClient(
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          backendApiClientProvider.overrideWithValue(apiClient),
          shopIdProvider.overrideWith(
            () => ShopIdNotifier(initialShopId: offlineOnlyShopId),
          ),
        ],
        child: MyApp(router: router),
      ),
    );
    await tester.pump();
    expect(
      find.text(
        'Without signing in, records stay in a separate local-only shop and will not sync after you sign in.',
      ),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextFormField).at(0), '0911223344');
    await tester.enterText(find.byType(TextFormField).at(1), '1234');
    await tester.tap(find.text('Sign In'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect((await tokenStore.read())?.shopId, shopId);
    expect(router.routeInformationProvider.value.uri.path, '/dashboard');

    final savedScope = await (database.select(
      database.syncState,
    )..where((row) => row.id.equals(1))).getSingle();
    expect(savedScope.activeShopId, shopId);

    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    await tester.pump(const Duration(seconds: 1));
    await database.close();
  });

  testWidgets('manual sync action uses the authenticated backend client', (
    WidgetTester tester,
  ) async {
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
    final router = createAppRouter(initialLocation: '/more');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          backendApiClientProvider.overrideWithValue(apiClient),
          shopIdProvider.overrideWith(
            () => ShopIdNotifier(initialShopId: shopId),
          ),
        ],
        child: MyApp(router: router),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Sync Now'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Sync completed successfully'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    await tester.pump(const Duration(seconds: 1));
    await database.close();
  });

  testWidgets('app renders splash branding and localization configuration', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MyApp(initialLocation: '/splash')),
    );
    await tester.pump();

    expect(find.text('Astawash'), findsOneWidget);
    expect(find.text('Keep track. Grow together.'), findsOneWidget);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final languageCodes = app.supportedLocales
        .map((locale) => locale.languageCode)
        .toSet();
    expect(languageCodes, containsAll(['en', 'am']));
    expect(app.theme?.textTheme.bodyMedium?.fontFamily, 'NotoSansEthiopic');
    expect(
      (await rootBundle.load(
        'assets/fonts/NotoSansEthiopic.ttf',
      )).lengthInBytes,
      greaterThan(0),
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });
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
