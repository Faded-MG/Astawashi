import 'package:astawash/core/db/app_database.dart';
import 'package:astawash/core/sync/sync_api.dart';
import 'package:astawash/core/sync/sync_engine.dart';
import 'package:astawash/core/sync/sync_models.dart';
import 'package:astawash/features/ledger/data/local_ledger_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late LocalLedgerRepository ledger;
  late FakeSyncApi api;
  late SyncEngine engine;

  final fixedTime = DateTime.utc(2026, 10, 23, 18);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    ledger = LocalLedgerRepository(
      database,
      shopId: 'shop-1',
      deviceId: 'device-1',
      clock: () => fixedTime,
    );
    api = FakeSyncApi();
    engine = SyncEngine(database: database, api: api, clock: () => fixedTime);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'pushes offline-created customers before entries and acknowledges them',
    () async {
      final customer = await ledger.addCustomer(name: 'Abebe');
      final entry = await ledger.addCredit(
        customerId: customer.id,
        amountSantim: 2550,
      );

      expect(
        (await database.select(database.customers).getSingle()).syncedAt
            ?.toUtc(),
        isNull,
      );
      expect(
        (await database.select(database.ledgerEntries).getSingle()).syncedAt
            ?.toUtc(),
        isNull,
      );

      final report = await engine.synchronize();

      expect(report.customersPushed, 1);
      expect(report.entriesPushed, 1);
      expect(api.pushCalls, 1);
      expect(api.lastPushedCustomers.single.id, customer.id);
      expect(api.lastPushedEntries.single.id, entry.id);
      expect(api.lastPushedEntries.single.amountSantim, 2550);
      expect(api.customerIdsAccepted, contains(customer.id));
      expect(api.entryIdsAccepted, contains(entry.id));
      expect(
        (await database.select(database.customers).getSingle()).syncedAt
            ?.toUtc(),
        fixedTime,
      );
      expect(
        (await database.select(database.ledgerEntries).getSingle()).syncedAt
            ?.toUtc(),
        fixedTime,
      );
    },
  );

  test(
    'preserves pending records after a network failure and retries idempotently',
    () async {
      final customer = await ledger.addCustomer(name: 'Chaltu');
      await ledger.addCredit(customerId: customer.id, amountSantim: 750);
      api.failNextPush = true;

      await expectLater(engine.synchronize(), throwsA(isA<SyncApiException>()));
      expect(
        (await database.select(database.customers).getSingle()).syncedAt,
        isNull,
      );
      expect(
        (await database.select(database.ledgerEntries).getSingle()).syncedAt,
        isNull,
      );

      final retry = await engine.synchronize();
      expect(retry.customersPushed, 1);
      expect(retry.entriesPushed, 1);
      expect(api.remoteCustomerIds, {customer.id});
      expect(api.remoteEntryIds, hasLength(1));
      expect(api.pushCalls, 2);
    },
  );

  test(
    'acknowledges accepted changes only and preserves rejected pending data',
    () async {
      final accepted = await ledger.addCustomer(name: 'Accepted');
      final rejected = await ledger.addCustomer(name: 'Rejected');
      api.rejectedCustomerIds.add(rejected.id);

      await expectLater(
        engine.synchronize(),
        throwsA(isA<SyncRejectedChangesException>()),
      );

      final rows = await database.select(database.customers).get();
      expect(
        rows.singleWhere((row) => row.id == accepted.id).syncedAt,
        isNotNull,
      );
      expect(rows.singleWhere((row) => row.id == rejected.id).syncedAt, isNull);
    },
  );

  test('expired authentication preserves local pending data', () async {
    final customer = await ledger.addCustomer(name: 'Offline');
    api.failWithAuthentication = true;

    await expectLater(
      engine.synchronize(),
      throwsA(isA<AuthenticationRequiredException>()),
    );

    final saved = await database.select(database.customers).getSingle();
    expect(saved.id, customer.id);
    expect(saved.syncedAt, isNull);
  });

  test(
    'applies pulled records transactionally and repeated IDs do not duplicate',
    () async {
      final customer = _remoteCustomer(id: 'remote-customer', serverSeq: 1);
      final entry = _remoteEntry(
        id: 'remote-entry',
        customerId: customer.id,
        serverSeq: 2,
      );
      api.pullPages.add(
        SyncPullPage(
          customers: [customer],
          entries: [entry],
          hasMore: false,
          nextCursor: BigInt.from(2),
        ),
      );
      api.pullPages.add(
        SyncPullPage(
          customers: const [],
          entries: const [],
          hasMore: false,
          nextCursor: null,
        ),
      );

      final first = await engine.synchronize();
      expect(first.customersPulled, 1);
      expect(first.entriesPulled, 1);
      expect(await database.select(database.customers).get(), hasLength(1));
      expect(await database.select(database.ledgerEntries).get(), hasLength(1));
      expect(await ledger.getOutstandingBalance(customer.id), 1200);

      api.pullPages.add(
        SyncPullPage(
          customers: [customer.copyWithServerSeq(BigInt.from(3))],
          entries: [entry.copyWithServerSeq(BigInt.from(4))],
          hasMore: false,
          nextCursor: BigInt.from(4),
        ),
      );
      await engine.synchronize();
      expect(await database.select(database.customers).get(), hasLength(1));
      expect(await database.select(database.ledgerEntries).get(), hasLength(1));
      expect(await ledger.getTotalOutstanding(), 1200);
    },
  );

  test(
    'rolls back pulled records and keeps the prior cursor when page application fails',
    () async {
      final customer = _remoteCustomer(id: 'page-customer', serverSeq: 1);
      final entry = _remoteEntry(
        id: 'invalid-entry',
        customerId: 'missing-customer',
        serverSeq: 2,
      );
      api.pullPages.add(
        SyncPullPage(
          customers: [customer],
          entries: [entry],
          hasMore: false,
          nextCursor: BigInt.from(2),
        ),
      );

      await expectLater(
        engine.synchronize(),
        throwsA(isA<SyncConflictException>()),
      );

      expect(await database.select(database.customers).get(), isEmpty);
      expect(await database.select(database.ledgerEntries).get(), isEmpty);
      expect(await database.select(database.syncState).get(), isEmpty);
    },
  );
}

class FakeSyncApi implements SyncApi {
  @override
  final String shopId = 'shop-1';

  int pushCalls = 0;
  bool failNextPush = false;
  bool failWithAuthentication = false;
  final Set<String> rejectedCustomerIds = {};
  final Set<String> remoteCustomerIds = {};
  final Set<String> remoteEntryIds = {};
  final List<SyncCustomerData> lastPushedCustomers = [];
  final List<SyncEntryData> lastPushedEntries = [];
  final List<SyncPullPage> pullPages = [];

  Set<String> get customerIdsAccepted => remoteCustomerIds;
  Set<String> get entryIdsAccepted => remoteEntryIds;

  @override
  Future<PushAcknowledgements> push({
    required List<SyncCustomerData> customers,
    required List<SyncEntryData> entries,
  }) async {
    pushCalls++;
    if (failWithAuthentication) {
      throw const AuthenticationRequiredException();
    }
    if (failNextPush) {
      failNextPush = false;
      throw const SyncApiException(message: 'Network timeout.');
    }

    lastPushedCustomers
      ..clear()
      ..addAll(customers);
    lastPushedEntries
      ..clear()
      ..addAll(entries);
    final acceptedCustomers = customers
        .where((customer) => !rejectedCustomerIds.contains(customer.id))
        .map((customer) => customer.id)
        .toList();
    final rejectedCustomers = customers
        .where((customer) => rejectedCustomerIds.contains(customer.id))
        .map(
          (customer) =>
              RejectedSyncChange(id: customer.id, reason: 'Rejected in test.'),
        )
        .toList();
    remoteCustomerIds.addAll(acceptedCustomers);
    remoteEntryIds.addAll(entries.map((entry) => entry.id));
    return PushAcknowledgements(
      acceptedCustomerIds: acceptedCustomers,
      acceptedEntryIds: entries.map((entry) => entry.id).toList(),
      alreadyAcceptedCustomerIds: const [],
      alreadyAcceptedEntryIds: const [],
      rejectedCustomers: rejectedCustomers,
      rejectedEntries: const [],
    );
  }

  @override
  Future<SyncPullPage> pull({required BigInt since, required int limit}) async {
    if (failWithAuthentication) {
      throw const AuthenticationRequiredException();
    }
    if (pullPages.isEmpty) {
      return const SyncPullPage(
        customers: [],
        entries: [],
        hasMore: false,
        nextCursor: null,
      );
    }
    return pullPages.removeAt(0);
  }
}

SyncCustomerData _remoteCustomer({required String id, required int serverSeq}) {
  final date = DateTime.utc(2026, 10, 23, 19);
  return SyncCustomerData(
    id: id,
    name: 'Remote customer',
    phone: null,
    note: null,
    createdAt: date,
    updatedAt: date,
    deletedAt: null,
    shopId: 'shop-1',
    serverSeq: BigInt.from(serverSeq),
  );
}

SyncEntryData _remoteEntry({
  required String id,
  required String customerId,
  required int serverSeq,
}) {
  final date = DateTime.utc(2026, 10, 23, 19, 1);
  return SyncEntryData(
    id: id,
    customerId: customerId,
    kind: 'credit',
    amountSantim: 1200,
    deltaSantim: 1200,
    reversesId: null,
    note: null,
    occurredAt: date,
    createdAt: date,
    deviceId: 'remote-device',
    shopId: 'shop-1',
    serverSeq: BigInt.from(serverSeq),
  );
}

extension on SyncCustomerData {
  SyncCustomerData copyWithServerSeq(BigInt serverSeq) => SyncCustomerData(
    id: id,
    name: name,
    phone: phone,
    note: note,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
    shopId: shopId,
    serverSeq: serverSeq,
  );
}

extension on SyncEntryData {
  SyncEntryData copyWithServerSeq(BigInt serverSeq) => SyncEntryData(
    id: id,
    customerId: customerId,
    kind: kind,
    amountSantim: amountSantim,
    deltaSantim: deltaSantim,
    reversesId: reversesId,
    note: note,
    occurredAt: occurredAt,
    createdAt: createdAt,
    deviceId: deviceId,
    shopId: shopId,
    serverSeq: serverSeq,
  );
}
