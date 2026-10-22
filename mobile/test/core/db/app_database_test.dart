import 'package:astawash/core/db/app_database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('AppDatabase Lifecycle & Initial Schema', () {
    test('database opens with schema version 1 and closes cleanly', () async {
      expect(db.schemaVersion, equals(1));
      // Simple query to verify connection is open and active
      final customers = await db.select(db.customers).get();
      expect(customers, isEmpty);
    });

    test('initial schema tables are queryable and empty on creation', () async {
      final customers = await db.select(db.customers).get();
      final entries = await db.select(db.ledgerEntries).get();
      final syncStates = await db.select(db.syncState).get();

      expect(customers, isEmpty);
      expect(entries, isEmpty);
      expect(syncStates, isEmpty);
    });
  });

  group('Customers Table', () {
    test('inserts and retrieves customer with all fields', () async {
      final now = DateTime.utc(2026, 10, 23, 12, 0, 0);

      await db
          .into(db.customers)
          .insert(
            CustomersCompanion.insert(
              id: 'cust-1',
              shopId: 'shop-1',
              name: 'Abebe Kebede',
              phone: const Value('0911223344'),
              note: const Value('Regular morning customer'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final customer = await (db.select(
        db.customers,
      )..where((c) => c.id.equals('cust-1'))).getSingle();

      expect(customer.id, equals('cust-1'));
      expect(customer.shopId, equals('shop-1'));
      expect(customer.name, equals('Abebe Kebede'));
      expect(customer.phone, equals('0911223344'));
      expect(customer.note, equals('Regular morning customer'));
      expect(customer.createdAt.toUtc(), equals(now.toUtc()));
      expect(customer.updatedAt.toUtc(), equals(now.toUtc()));
      expect(customer.deletedAt, isNull);
      expect(customer.syncedAt, isNull);
      expect(customer.serverSeq, isNull);
    });

    test('allows updating customer details and soft deletion', () async {
      final now = DateTime.utc(2026, 10, 23, 12, 0, 0);
      final updatedTime = now.add(const Duration(hours: 1));

      await db
          .into(db.customers)
          .insert(
            CustomersCompanion.insert(
              id: 'cust-2',
              shopId: 'shop-1',
              name: 'Almaz',
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Update name and phone
      await (db.update(
        db.customers,
      )..where((c) => c.id.equals('cust-2'))).write(
        CustomersCompanion(
          name: const Value('Almaz Tesfaye'),
          phone: const Value('0922334455'),
          updatedAt: Value(updatedTime),
        ),
      );

      var customer = await (db.select(
        db.customers,
      )..where((c) => c.id.equals('cust-2'))).getSingle();
      expect(customer.name, equals('Almaz Tesfaye'));
      expect(customer.phone, equals('0922334455'));

      // Soft delete
      final deletedTime = updatedTime.add(const Duration(days: 1));
      await (db.update(
        db.customers,
      )..where((c) => c.id.equals('cust-2'))).write(
        CustomersCompanion(
          deletedAt: Value(deletedTime),
          updatedAt: Value(deletedTime),
        ),
      );

      customer = await (db.select(
        db.customers,
      )..where((c) => c.id.equals('cust-2'))).getSingle();
      expect(customer.deletedAt?.toUtc(), equals(deletedTime.toUtc()));
    });
  });

  group('SyncState Table', () {
    test('inserts and retrieves sync cursor state', () async {
      await db
          .into(db.syncState)
          .insert(
            SyncStateCompanion.insert(lastPullSeq: Value(BigInt.from(12345))),
          );

      final state = await db.select(db.syncState).getSingle();
      expect(state.lastPullSeq, equals(BigInt.from(12345)));
    });
  });

  group('LedgerEntries Table & Constraints', () {
    final now = DateTime.utc(2026, 10, 23, 12, 0, 0);

    setUp(() async {
      // Seed a customer for foreign key tests
      await db
          .into(db.customers)
          .insert(
            CustomersCompanion.insert(
              id: 'cust-1',
              shopId: 'shop-1',
              name: 'Abebe',
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    test('inserts and retrieves valid credit and payment entries', () async {
      // Credit sale of 25.50 Birr (2550 santim)
      await db
          .into(db.ledgerEntries)
          .insert(
            LedgerEntriesCompanion.insert(
              id: 'entry-1',
              shopId: 'shop-1',
              customerId: 'cust-1',
              kind: 'credit',
              amountSantim: 2550,
              deltaSantim: 2550,
              occurredAt: now,
              createdAt: now,
              deviceId: 'dev-1',
            ),
          );

      // Repayment of 10.00 Birr (1000 santim)
      await db
          .into(db.ledgerEntries)
          .insert(
            LedgerEntriesCompanion.insert(
              id: 'entry-2',
              shopId: 'shop-1',
              customerId: 'cust-1',
              kind: 'payment',
              amountSantim: 1000,
              deltaSantim: -1000,
              occurredAt: now,
              createdAt: now,
              deviceId: 'dev-1',
            ),
          );

      final entries = await db.select(db.ledgerEntries).get();
      expect(entries.length, equals(2));
      expect(entries[0].amountSantim, equals(2550));
      expect(entries[0].deltaSantim, equals(2550));
      expect(entries[1].amountSantim, equals(1000));
      expect(entries[1].deltaSantim, equals(-1000));
    });

    test('rejects amountSantim <= 0 via CHECK constraint', () async {
      // Zero amount
      expect(
        () => db
            .into(db.ledgerEntries)
            .insert(
              LedgerEntriesCompanion.insert(
                id: 'entry-zero',
                shopId: 'shop-1',
                customerId: 'cust-1',
                kind: 'credit',
                amountSantim: 0,
                deltaSantim: 0,
                occurredAt: now,
                createdAt: now,
                deviceId: 'dev-1',
              ),
            ),
        throwsA(isA<SqliteException>()),
      );

      // Negative amount
      expect(
        () => db
            .into(db.ledgerEntries)
            .insert(
              LedgerEntriesCompanion.insert(
                id: 'entry-neg',
                shopId: 'shop-1',
                customerId: 'cust-1',
                kind: 'credit',
                amountSantim: -500,
                deltaSantim: -500,
                occurredAt: now,
                createdAt: now,
                deviceId: 'dev-1',
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('rejects invalid kind via CHECK constraint', () async {
      expect(
        () => db
            .into(db.ledgerEntries)
            .insert(
              LedgerEntriesCompanion.insert(
                id: 'entry-invalid-kind',
                shopId: 'shop-1',
                customerId: 'cust-1',
                kind: 'refund',
                amountSantim: 1000,
                deltaSantim: 1000,
                occurredAt: now,
                createdAt: now,
                deviceId: 'dev-1',
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('enforces foreign key for customerId', () async {
      expect(
        () => db
            .into(db.ledgerEntries)
            .insert(
              LedgerEntriesCompanion.insert(
                id: 'entry-fk-fail',
                shopId: 'shop-1',
                customerId: 'non-existent-customer',
                kind: 'credit',
                amountSantim: 1000,
                deltaSantim: 1000,
                occurredAt: now,
                createdAt: now,
                deviceId: 'dev-1',
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('enforces foreign key for reversesId', () async {
      expect(
        () => db
            .into(db.ledgerEntries)
            .insert(
              LedgerEntriesCompanion.insert(
                id: 'reversal-fk-fail',
                shopId: 'shop-1',
                customerId: 'cust-1',
                kind: 'reversal',
                amountSantim: 1000,
                deltaSantim: -1000,
                reversesId: const Value('non-existent-entry'),
                occurredAt: now,
                createdAt: now,
                deviceId: 'dev-1',
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test(
      'enforces unique reverses_id (an entry can only be reversed once)',
      () async {
        // Create initial credit sale
        await db
            .into(db.ledgerEntries)
            .insert(
              LedgerEntriesCompanion.insert(
                id: 'orig-entry',
                shopId: 'shop-1',
                customerId: 'cust-1',
                kind: 'credit',
                amountSantim: 2000,
                deltaSantim: 2000,
                occurredAt: now,
                createdAt: now,
                deviceId: 'dev-1',
              ),
            );

        // First reversal succeeds
        await db
            .into(db.ledgerEntries)
            .insert(
              LedgerEntriesCompanion.insert(
                id: 'rev-1',
                shopId: 'shop-1',
                customerId: 'cust-1',
                kind: 'reversal',
                amountSantim: 2000,
                deltaSantim: -2000,
                reversesId: const Value('orig-entry'),
                occurredAt: now,
                createdAt: now,
                deviceId: 'dev-1',
              ),
            );

        // Second reversal of the same entry fails with UNIQUE constraint
        expect(
          () => db
              .into(db.ledgerEntries)
              .insert(
                LedgerEntriesCompanion.insert(
                  id: 'rev-2',
                  shopId: 'shop-1',
                  customerId: 'cust-1',
                  kind: 'reversal',
                  amountSantim: 2000,
                  deltaSantim: -2000,
                  reversesId: const Value('orig-entry'),
                  occurredAt: now,
                  createdAt: now,
                  deviceId: 'dev-1',
                ),
              ),
          throwsA(isA<SqliteException>()),
        );
      },
    );
  });

  group('Immutability Triggers (Append-Only Enforcement)', () {
    final now = DateTime.utc(2026, 10, 23, 12, 0, 0);

    setUp(() async {
      await db
          .into(db.customers)
          .insert(
            CustomersCompanion.insert(
              id: 'cust-1',
              shopId: 'shop-1',
              name: 'Abebe',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db
          .into(db.ledgerEntries)
          .insert(
            LedgerEntriesCompanion.insert(
              id: 'entry-1',
              shopId: 'shop-1',
              customerId: 'cust-1',
              kind: 'credit',
              amountSantim: 5000,
              deltaSantim: 5000,
              occurredAt: now,
              createdAt: now,
              deviceId: 'dev-1',
            ),
          );
    });

    test('prohibits DELETE on ledger_entries via database trigger', () async {
      expect(
        () => (db.delete(
          db.ledgerEntries,
        )..where((e) => e.id.equals('entry-1'))).go(),
        throwsA(
          isA<SqliteException>().having(
            (e) => e.message,
            'message',
            contains('ledger_entries is append-only: deletes are prohibited'),
          ),
        ),
      );

      // Ensure row was not deleted
      final entries = await db.select(db.ledgerEntries).get();
      expect(entries.length, equals(1));
    });

    test(
      'prohibits UPDATE of financial and audit columns via database trigger',
      () async {
        // Attempting to change amountSantim
        expect(
          () =>
              (db.update(
                db.ledgerEntries,
              )..where((e) => e.id.equals('entry-1'))).write(
                const LedgerEntriesCompanion(amountSantim: Value(3000)),
              ),
          throwsA(
            isA<SqliteException>().having(
              (e) => e.message,
              'message',
              contains(
                'ledger_entries is append-only: financial and audit columns cannot be modified',
              ),
            ),
          ),
        );

        // Attempting to change deltaSantim
        expect(
          () =>
              (db.update(
                db.ledgerEntries,
              )..where((e) => e.id.equals('entry-1'))).write(
                const LedgerEntriesCompanion(deltaSantim: Value(3000)),
              ),
          throwsA(isA<SqliteException>()),
        );

        // Attempting to change kind
        expect(
          () =>
              (db.update(db.ledgerEntries)
                    ..where((e) => e.id.equals('entry-1')))
                  .write(const LedgerEntriesCompanion(kind: Value('payment'))),
          throwsA(isA<SqliteException>()),
        );
      },
    );

    test('permits updating sync metadata (syncedAt and serverSeq)', () async {
      final syncTime = DateTime.utc(2026, 10, 23, 12, 5, 0);
      final seq = BigInt.from(42);

      await (db.update(
        db.ledgerEntries,
      )..where((e) => e.id.equals('entry-1'))).write(
        LedgerEntriesCompanion(
          syncedAt: Value(syncTime),
          serverSeq: Value(seq),
        ),
      );

      final entry = await (db.select(
        db.ledgerEntries,
      )..where((e) => e.id.equals('entry-1'))).getSingle();

      expect(entry.syncedAt?.toUtc(), equals(syncTime.toUtc()));
      expect(entry.serverSeq, equals(seq));
      // Financial amounts remain untouched
      expect(entry.amountSantim, equals(5000));
      expect(entry.deltaSantim, equals(5000));
    });
  });
}
