import 'dart:async';

import 'package:astawash/app/providers/app_providers.dart';
import 'package:astawash/app/router/app_router.dart';
import 'package:astawash/app/theme/app_theme.dart';
import 'package:astawash/core/db/app_database.dart';
import 'package:astawash/core/l10n/app_localizations.dart';
import 'package:astawash/core/sync/backend_api_client.dart';
import 'package:astawash/core/sync/token_store.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase();
  final apiClient = await BackendApiClient.restore(
    baseUrl: backendBaseUrl,
    tokenStore: SecureTokenStore(),
  );
  final savedState = await (database.select(
    database.syncState,
  )..where((row) => row.id.equals(1))).getSingleOrNull();
  final activeShopId = apiClient.isAuthenticated
      ? apiClient.shopId
      : savedState?.activeShopId ?? offlineOnlyShopId;

  if (apiClient.isAuthenticated) {
    await database
        .into(database.syncState)
        .insertOnConflictUpdate(
          SyncStateCompanion(
            id: const Value(1),
            activeShopId: Value(activeShopId),
          ),
        );
  }

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWith((ref) {
          ref.onDispose(() => unawaited(database.close()));
          return database;
        }),
        backendApiClientProvider.overrideWithValue(apiClient),
        shopIdProvider.overrideWith(
          () => ShopIdNotifier(initialShopId: activeShopId),
        ),
      ],
      child: MyApp(
        initialLocation: apiClient.isAuthenticated ? '/dashboard' : '/splash',
      ),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key, this.router, this.initialLocation});

  final GoRouter? router;
  final String? initialLocation;

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  late final GoRouter _router =
      widget.router ??
      createAppRouter(initialLocation: widget.initialLocation ?? '/splash');

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
      title: 'Astawash',
      routerConfig: _router,
      theme: AppTheme.lightTheme,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
    );
  }
}
