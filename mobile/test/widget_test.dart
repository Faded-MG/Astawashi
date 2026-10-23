import 'dart:convert';

import 'package:astawash/core/db/app_database.dart';
import 'package:astawash/core/sync/backend_api_client.dart';
import 'package:astawash/core/sync/sync_models.dart';
import 'package:astawash/core/sync/token_store.dart';
import 'package:astawash/main.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const shopId = '22222222-2222-4222-8222-222222222222';

  testWidgets('signs in and manually triggers sync from the app', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    final apiClient = BackendApiClient(
      baseUrl: 'https://api.example.test',
      tokenStore: _MemoryTokenStore(),
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

    await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
    expect(
      find.text(
        'Your local ledger stays available without internet. Sign in when you are online to synchronize.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Synchronize now'), findsOneWidget);

    await tester.tap(find.text('Synchronize now'));
    await tester.pumpAndSettle();
    expect(find.text('Synchronization complete'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('app supports English and Amharic with bundled Ethiopic font', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    final apiClient = BackendApiClient(
      baseUrl: 'https://api.example.test',
      tokenStore: _MemoryTokenStore(),
    );
    await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));

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
  SessionTokens? _tokens;

  @override
  Future<void> clear() async => _tokens = null;

  @override
  Future<SessionTokens?> read() async => _tokens;

  @override
  Future<void> save(SessionTokens tokens) async => _tokens = tokens;
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
