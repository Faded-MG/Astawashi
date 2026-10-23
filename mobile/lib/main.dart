import 'dart:async';

import 'package:astawash/core/db/app_database.dart';
import 'package:astawash/core/l10n/app_localizations.dart';
import 'package:astawash/core/sync/app_sync_controller.dart';
import 'package:astawash/core/sync/backend_api_client.dart';
import 'package:astawash/core/sync/token_store.dart';
import 'package:flutter/material.dart';

const backendBaseUrl = String.fromEnvironment(
  'ASTAWASH_API_BASE_URL',
  defaultValue: 'http://localhost:3000',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase();
  final apiClient = await BackendApiClient.restore(
    baseUrl: backendBaseUrl,
    tokenStore: SecureTokenStore(),
  );
  runApp(MyApp(database: database, apiClient: apiClient));
}

class MyApp extends StatefulWidget {
  const MyApp({required this.database, required this.apiClient, super.key});

  final AppDatabase database;
  final BackendApiClient apiClient;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppSyncController _controller = AppSyncController(
    database: widget.database,
    apiClient: widget.apiClient,
  );

  @override
  void dispose() {
    _controller.dispose();
    widget.database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Astawash',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        fontFamily: 'NotoSansEthiopic',
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: SyncHomePage(controller: _controller),
    );
  }
}

class SyncHomePage extends StatefulWidget {
  const SyncHomePage({required this.controller, super.key});

  final AppSyncController controller;

  @override
  State<SyncHomePage> createState() => _SyncHomePageState();
}

class _SyncHomePageState extends State<SyncHomePage> {
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _shopNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant SyncHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _phoneController.dispose();
    _pinController.dispose();
    _shopNameController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _login() => widget.controller.login(
    phone: _phoneController.text.trim(),
    pin: _pinController.text,
  );

  Future<void> _register() => widget.controller.register(
    phone: _phoneController.text.trim(),
    pin: _pinController.text,
    shopName: _shopNameController.text.trim().isEmpty
        ? null
        : _shopNameController.text.trim(),
  );

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final controller = widget.controller;
    final isBusy =
        controller.isAuthenticating ||
        controller.status == AppSyncStatus.syncing;
    final report = controller.lastReport;

    return Scaffold(
      appBar: AppBar(title: Text(strings.appTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(strings.offlineDescription),
          const SizedBox(height: 24),
          if (!controller.isAuthenticated) ...[
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: strings.phoneLabel),
            ),
            TextField(
              controller: _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: strings.pinLabel),
            ),
            TextField(
              controller: _shopNameController,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(labelText: strings.shopNameLabel),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: isBusy ? null : () => unawaited(_login()),
                  child: Text(strings.loginButton),
                ),
                OutlinedButton(
                  onPressed: isBusy ? null : () => unawaited(_register()),
                  child: Text(strings.registerButton),
                ),
              ],
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: isBusy
                  ? null
                  : () => unawaited(controller.synchronize()),
              icon: controller.status == AppSyncStatus.syncing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: Text(strings.syncButton),
            ),
          ],
          const SizedBox(height: 20),
          Text(_statusText(strings, controller)),
          if (controller.errorMessage case final message?) ...[
            const SizedBox(height: 8),
            SelectableText(
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (report != null && controller.status == AppSyncStatus.success) ...[
            const SizedBox(height: 8),
            Text(
              strings.syncResult(report.customersPushed, report.entriesPushed),
            ),
          ],
        ],
      ),
    );
  }

  String _statusText(AppLocalizations strings, AppSyncController controller) {
    return switch (controller.status) {
      AppSyncStatus.idle =>
        controller.isAuthenticated
            ? strings.syncIdle
            : strings.authenticationRequired,
      AppSyncStatus.syncing => strings.syncInProgress,
      AppSyncStatus.success => strings.syncSucceeded,
      AppSyncStatus.failure =>
        controller.isAuthenticated
            ? strings.syncFailed
            : strings.authenticationFailed,
    };
  }
}
