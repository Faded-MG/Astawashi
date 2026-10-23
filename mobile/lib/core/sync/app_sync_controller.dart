import 'package:flutter/foundation.dart';

import '../db/app_database.dart';
import 'backend_api_client.dart';
import 'sync_api.dart';
import 'sync_engine.dart';

enum AppSyncStatus { idle, syncing, success, failure }

class AppSyncController extends ChangeNotifier {
  AppSyncController({
    required AppDatabase database,
    required BackendApiClient apiClient,
  }) : _apiClient = apiClient,
       _syncEngine = SyncEngine(database: database, api: apiClient),
       isAuthenticated = apiClient.isAuthenticated;

  final BackendApiClient _apiClient;
  final SyncEngine _syncEngine;

  bool isAuthenticated;
  bool isAuthenticating = false;
  AppSyncStatus status = AppSyncStatus.idle;
  SyncReport? lastReport;
  String? errorMessage;

  Future<void> login({required String phone, required String pin}) {
    return _authenticate(() => _apiClient.login(phone: phone, pin: pin));
  }

  Future<void> register({
    required String phone,
    required String pin,
    String? shopName,
  }) {
    return _authenticate(
      () => _apiClient.register(phone: phone, pin: pin, shopName: shopName),
    );
  }

  Future<void> _authenticate(Future<String> Function() authenticate) async {
    if (isAuthenticating) return;
    isAuthenticating = true;
    errorMessage = null;
    notifyListeners();
    try {
      await authenticate();
      isAuthenticated = true;
      status = AppSyncStatus.idle;
    } catch (error) {
      errorMessage = _errorMessage(error);
    } finally {
      isAuthenticating = false;
      notifyListeners();
    }
  }

  Future<void> synchronize() async {
    if (status == AppSyncStatus.syncing) return;
    if (!isAuthenticated) {
      status = AppSyncStatus.failure;
      errorMessage = null;
      notifyListeners();
      return;
    }

    status = AppSyncStatus.syncing;
    errorMessage = null;
    notifyListeners();
    try {
      lastReport = await _syncEngine.synchronize();
      status = AppSyncStatus.success;
    } catch (error) {
      if (error is AuthenticationRequiredException) {
        isAuthenticated = false;
      }
      status = AppSyncStatus.failure;
      errorMessage = _errorMessage(error);
    }
    notifyListeners();
  }

  String _errorMessage(Object error) {
    if (error is SyncApiException) return error.message;
    return error.toString();
  }
}
