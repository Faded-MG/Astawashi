import 'dart:io';

import 'package:astawash/core/db/app_database.dart';
import 'package:astawash/core/sync/app_sync_controller.dart';
import 'package:astawash/core/sync/backend_api_client.dart';
import 'package:astawash/core/sync/sync_api.dart';
import 'package:astawash/core/sync/sync_engine.dart';
import 'package:astawash/core/sync/sync_models.dart';
import 'package:astawash/core/sync/token_store.dart';
import 'package:astawash/features/ledger/data/local_ledger_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final baseUrl = Platform.environment['ASTAWASH_TEST_API_BASE_URL'];

  test(
    'live backend: local push, server persistence, remote pull, retry and shop isolation',
    () async {
      final firstDatabase = AppDatabase(NativeDatabase.memory());
      var firstDatabaseClosed = false;
      addTearDown(() async {
        if (!firstDatabaseClosed) await firstDatabase.close();
      });
      final firstTokenStore = _MemoryTokenStore();
      final firstClient = BackendApiClient(
        baseUrl: baseUrl!,
        tokenStore: firstTokenStore,
      );
      final phone = _testPhone();
      const pin = '7341';

      await firstClient.register(
        phone: phone,
        pin: pin,
        shopName: 'Session 3C test shop',
      );
      final firstRepository = LocalLedgerRepository(
        firstDatabase,
        shopId: firstClient.shopId,
        deviceId: 'session-3c-device-a',
      );
      final customer = await firstRepository.addCustomer(
        name: 'Offline E2E customer',
      );
      final credit = await firstRepository.addCredit(
        customerId: customer.id,
        amountSantim: 12500,
      );
      final payment = await firstRepository.addPayment(
        customerId: customer.id,
        amountSantim: 2500,
      );
      expect(await firstRepository.getBalance(customer.id), 10000);
      expect(await firstRepository.getTotalOutstanding(), 10000);

      final unavailableClient = await BackendApiClient.restore(
        baseUrl: 'http://127.0.0.1:1',
        tokenStore: firstTokenStore,
      );
      final unavailableEngine = SyncEngine(
        database: firstDatabase,
        api: unavailableClient,
      );
      await expectLater(
        unavailableEngine.synchronize(),
        throwsA(isA<SyncApiException>()),
      );
      var pendingCustomer = await firstRepository.getCustomer(customer.id);
      expect(pendingCustomer?.syncedAt, isNull);
      expect(
        await (firstDatabase.select(
          firstDatabase.ledgerEntries,
        )..where((row) => row.customerId.equals(customer.id))).get(),
        everyElement(predicate<LedgerEntry>((entry) => entry.syncedAt == null)),
      );
      expect(await firstRepository.getBalance(customer.id), 10000);

      final appSyncController = AppSyncController(
        database: firstDatabase,
        apiClient: firstClient,
      );
      addTearDown(appSyncController.dispose);
      await appSyncController.synchronize();
      expect(appSyncController.status, AppSyncStatus.success);
      pendingCustomer = await firstRepository.getCustomer(customer.id);
      expect(pendingCustomer?.syncedAt, isNotNull);

      final serverPage = await firstClient.pull(since: BigInt.zero, limit: 200);
      expect(serverPage.customers.map((row) => row.id), contains(customer.id));
      expect(
        serverPage.entries.map((row) => row.id),
        containsAll([credit.id, payment.id]),
      );

      final storedCustomer = await firstRepository.getCustomer(customer.id);
      final storedEntries = await (firstDatabase.select(
        firstDatabase.ledgerEntries,
      )..where((row) => row.customerId.equals(customer.id))).get();
      final storedCredit = storedEntries.singleWhere(
        (entry) => entry.id == credit.id,
      );
      final storedPayment = storedEntries.singleWhere(
        (entry) => entry.id == payment.id,
      );
      final duplicatePush = await firstClient.push(
        customers: [
          SyncCustomerData(
            id: storedCustomer!.id,
            name: storedCustomer.name,
            phone: storedCustomer.phone,
            note: storedCustomer.note,
            createdAt: storedCustomer.createdAt,
            updatedAt: storedCustomer.updatedAt,
            deletedAt: storedCustomer.deletedAt,
          ),
        ],
        entries: [
          SyncEntryData(
            id: storedCredit.id,
            customerId: storedCredit.customerId,
            kind: storedCredit.kind,
            amountSantim: storedCredit.amountSantim,
            deltaSantim: storedCredit.deltaSantim,
            reversesId: storedCredit.reversesId,
            note: storedCredit.note,
            occurredAt: storedCredit.occurredAt,
            createdAt: storedCredit.createdAt,
            deviceId: storedCredit.deviceId,
          ),
          SyncEntryData(
            id: storedPayment.id,
            customerId: storedPayment.customerId,
            kind: storedPayment.kind,
            amountSantim: storedPayment.amountSantim,
            deltaSantim: storedPayment.deltaSantim,
            reversesId: storedPayment.reversesId,
            note: storedPayment.note,
            occurredAt: storedPayment.occurredAt,
            createdAt: storedPayment.createdAt,
            deviceId: storedPayment.deviceId,
          ),
        ],
      );
      expect(
        duplicatePush.alreadyAcceptedCustomerIds,
        contains(customer.id),
        reason:
            'accepted=${duplicatePush.acceptedCustomerIds}, rejected=${duplicatePush.rejectedCustomers.map((row) => row.reason)}',
      );
      expect(
        duplicatePush.alreadyAcceptedEntryIds,
        containsAll([credit.id, payment.id]),
      );

      await firstDatabase.close();
      firstDatabaseClosed = true;
      final secondTokenStore = _MemoryTokenStore();
      final secondClient = BackendApiClient(
        baseUrl: baseUrl,
        tokenStore: secondTokenStore,
      );
      await secondClient.login(phone: phone, pin: pin);
      final secondDatabase = AppDatabase(NativeDatabase.memory());
      var secondDatabaseClosed = false;
      addTearDown(() async {
        if (!secondDatabaseClosed) await secondDatabase.close();
      });
      final secondRepository = LocalLedgerRepository(
        secondDatabase,
        shopId: secondClient.shopId,
        deviceId: 'session-3c-device-b',
      );
      final secondEngine = SyncEngine(
        database: secondDatabase,
        api: secondClient,
      );
      await secondEngine.synchronize();
      expect(await secondRepository.getCustomer(customer.id), isNotNull);
      expect(await secondRepository.getBalance(customer.id), 10000);
      expect(await secondRepository.getTotalOutstanding(), 10000);
      await secondEngine.synchronize();
      expect(
        await (secondDatabase.select(
          secondDatabase.ledgerEntries,
        )..where((row) => row.customerId.equals(customer.id))).get(),
        hasLength(2),
      );
      expect(await secondRepository.getBalance(customer.id), 10000);

      final otherShopClient = BackendApiClient(
        baseUrl: baseUrl,
        tokenStore: _MemoryTokenStore(),
      );
      await otherShopClient.register(
        phone: _testPhone(),
        pin: pin,
        shopName: 'Session 3C isolation test',
      );
      final otherShopPage = await otherShopClient.pull(
        since: BigInt.zero,
        limit: 200,
      );
      expect(
        otherShopPage.customers.map((row) => row.id),
        isNot(contains(customer.id)),
      );
      expect(
        otherShopPage.entries.map((row) => row.id),
        isNot(contains(credit.id)),
      );
      final crossShopPush = await otherShopClient.push(
        customers: [
          SyncCustomerData(
            id: customer.id,
            name: customer.name,
            phone: customer.phone,
            note: customer.note,
            createdAt: customer.createdAt,
            updatedAt: customer.updatedAt,
            deletedAt: customer.deletedAt,
          ),
        ],
        entries: const [],
      );
      expect(crossShopPush.rejectedCustomers.map((row) => row.id), [
        customer.id,
      ]);
      await secondDatabase.close();
      secondDatabaseClosed = true;

      final crossShopEntryPush = await otherShopClient.push(
        customers: const [],
        entries: [
          SyncEntryData(
            id: '55555555-5555-4555-8555-555555555555',
            customerId: customer.id,
            kind: 'credit',
            amountSantim: 100,
            deltaSantim: 100,
            reversesId: null,
            note: null,
            occurredAt: DateTime.now().toUtc(),
            createdAt: DateTime.now().toUtc(),
            deviceId: 'session-3c-cross-shop-attempt',
          ),
        ],
      );
      expect(crossShopEntryPush.rejectedEntries.map((row) => row.id), [
        '55555555-5555-4555-8555-555555555555',
      ]);
    },
    skip: baseUrl == null
        ? 'Set ASTAWASH_TEST_API_BASE_URL to run against a live disposable backend.'
        : false,
  );
}

String _testPhone() {
  final timestamp = DateTime.now().microsecondsSinceEpoch.toString();
  return '+2519${timestamp.substring(timestamp.length - 9)}';
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
