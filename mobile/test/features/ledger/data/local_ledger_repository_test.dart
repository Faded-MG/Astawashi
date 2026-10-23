import 'package:astawash/core/db/app_database.dart';
import 'package:astawash/features/ledger/data/local_ledger_repository.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late LocalLedgerRepository repository;

  final fixedTime = DateTime.utc(2026, 10, 23, 12);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = LocalLedgerRepository(
      database,
      shopId: 'shop-1',
      deviceId: 'device-1',
      clock: () => fixedTime,
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<Customer> addCustomer([String name = 'Abebe Kebede']) {
    return repository.addCustomer(
      name: name,
      phone: '0911223344',
      note: 'Regular customer',
    );
  }

  group('customers', () {
    test('persists and retrieves customer details for this shop', () async {
      final customer = await addCustomer();

      expect(
        customer.id,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(customer.shopId, 'shop-1');
      expect(customer.name, 'Abebe Kebede');
      expect(customer.phone, '0911223344');
      expect(customer.note, 'Regular customer');
      expect(customer.createdAt, fixedTime);
      expect(customer.updatedAt, fixedTime);
      final retrieved = await repository.getCustomer(customer.id);
      expect(retrieved?.id, customer.id);
      expect(retrieved?.name, customer.name);
      expect(retrieved?.phone, customer.phone);
      expect(retrieved?.note, customer.note);
      expect(retrieved?.createdAt.toUtc(), fixedTime);
      expect(retrieved?.updatedAt.toUtc(), fixedTime);

      final watchedCustomers = await repository.watchCustomers().first;
      expect(watchedCustomers.map((entry) => entry.id), [customer.id]);
    });

    test('does not expose customers belonging to another shop', () async {
      final customer = await addCustomer();
      final otherShopRepository = LocalLedgerRepository(
        database,
        shopId: 'shop-2',
        deviceId: 'device-2',
      );

      expect(await otherShopRepository.getCustomer(customer.id), isNull);
      expect(await otherShopRepository.watchCustomers().first, isEmpty);
      await expectLater(
        otherShopRepository.addCredit(
          customerId: customer.id,
          amountSantim: 500,
        ),
        throwsArgumentError,
      );
      expect(await database.select(database.ledgerEntries).get(), isEmpty);
    });
  });

  group('credits, payments, and balances', () {
    test('records credit and partial then full repayments in santim', () async {
      final customer = await addCustomer();
      final credit = await repository.addCredit(
        customerId: customer.id,
        amountSantim: 2550,
        note: 'Market goods',
      );
      final partialPayment = await repository.addPayment(
        customerId: customer.id,
        amountSantim: 1000,
      );

      expect(credit.kind, 'credit');
      expect(credit.amountSantim, 2550);
      expect(credit.deltaSantim, 2550);
      expect(credit.deviceId, 'device-1');
      expect(credit.syncedAt, isNull);
      expect(partialPayment.kind, 'payment');
      expect(partialPayment.deltaSantim, -1000);
      expect(await repository.getOutstandingBalance(customer.id), 1550);

      await repository.addPayment(customerId: customer.id, amountSantim: 1550);
      expect(await repository.getOutstandingBalance(customer.id), 0);

      final entries = await database.select(database.ledgerEntries).get();
      expect(entries.map((entry) => entry.deltaSantim), [2550, -1000, -1550]);
    });

    test('balance and history streams update from ledger inserts', () async {
      final customer = await addCustomer();
      final balances = repository.watchOutstandingBalance(customer.id);
      final history = repository.watchHistory(customer.id);
      final balanceEvents = <int>[];
      final historyLengths = <int>[];
      final balanceSubscription = balances.listen(balanceEvents.add);
      final historySubscription = history.listen(
        (entries) => historyLengths.add(entries.length),
      );
      addTearDown(balanceSubscription.cancel);
      addTearDown(historySubscription.cancel);

      await Future<void>.delayed(Duration.zero);
      await repository.addCredit(customerId: customer.id, amountSantim: 2000);
      await Future<void>.delayed(Duration.zero);

      expect(balanceEvents, containsAllInOrder([0, 2000]));
      expect(historyLengths, containsAllInOrder([0, 1]));
    });

    test(
      'aggregates total outstanding across active customers and excludes soft-deleted ones',
      () async {
        final first = await addCustomer('Abebe Kebede');
        final second = await addCustomer('Chaltu Bekele');

        await repository.addCredit(customerId: first.id, amountSantim: 2500);
        await repository.addPayment(customerId: first.id, amountSantim: 1000);
        await repository.addCredit(customerId: second.id, amountSantim: 1200);

        expect(await repository.getTotalOutstanding(), 2700);
        expect(await repository.getBalance(first.id), 1500);
        expect(await repository.watchTotalOutstanding().first, 2700);
        expect(await repository.watchBalance(first.id).first, 1500);

        await (database.update(
          database.customers,
        )..where((customer) => customer.id.equals(second.id))).write(
          CustomersCompanion(
            deletedAt: Value(fixedTime.add(const Duration(minutes: 5))),
            updatedAt: Value(fixedTime.add(const Duration(minutes: 5))),
          ),
        );

        expect(await repository.getTotalOutstanding(), 1500);
        expect(await repository.watchTotalOutstanding().first, 1500);
      },
    );

    test(
      'rejects zero and negative transaction amounts without writes',
      () async {
        final customer = await addCustomer();

        await expectLater(
          repository.addCredit(customerId: customer.id, amountSantim: 0),
          throwsArgumentError,
        );
        await expectLater(
          repository.addCredit(customerId: customer.id, amountSantim: -1),
          throwsArgumentError,
        );
        await expectLater(
          repository.addPayment(customerId: customer.id, amountSantim: 0),
          throwsArgumentError,
        );

        expect(await database.select(database.ledgerEntries).get(), isEmpty);
        expect(await repository.getOutstandingBalance(customer.id), 0);
      },
    );

    test('rejects overpayment and leaves the ledger unchanged', () async {
      final customer = await addCustomer();
      await repository.addCredit(customerId: customer.id, amountSantim: 1000);

      await expectLater(
        repository.addPayment(customerId: customer.id, amountSantim: 1001),
        throwsStateError,
      );

      final entries = await database.select(database.ledgerEntries).get();
      expect(entries, hasLength(1));
      expect(await repository.getOutstandingBalance(customer.id), 1000);
    });

    test('serializes concurrent repayments to prevent overpayment', () async {
      final customer = await addCustomer();
      await repository.addCredit(customerId: customer.id, amountSantim: 500);

      final outcomes = await Future.wait([
        repository
            .addPayment(customerId: customer.id, amountSantim: 400)
            .then((_) => true, onError: (Object _) => false),
        repository
            .addPayment(customerId: customer.id, amountSantim: 400)
            .then((_) => true, onError: (Object _) => false),
      ]);

      expect(outcomes.where((succeeded) => succeeded), hasLength(1));
      expect(await repository.getOutstandingBalance(customer.id), 100);
      expect(await database.select(database.ledgerEntries).get(), hasLength(2));
    });
  });

  group('reversals', () {
    test(
      'adds exact inverse entries without changing original entries',
      () async {
        final customer = await addCustomer();
        final credit = await repository.addCredit(
          customerId: customer.id,
          amountSantim: 2500,
        );
        final reversal = await repository.reverseEntry(
          entryId: credit.id,
          note: 'Entered in error',
        );

        expect(reversal.kind, 'reversal');
        expect(reversal.amountSantim, 2500);
        expect(reversal.deltaSantim, -2500);
        expect(reversal.reversesId, credit.id);
        expect(await repository.getOutstandingBalance(customer.id), 0);

        final entries = await database.select(database.ledgerEntries).get();
        expect(entries, hasLength(2));
        final storedCredit = entries.firstWhere(
          (entry) => entry.id == credit.id,
        );
        expect(storedCredit.amountSantim, credit.amountSantim);
        expect(storedCredit.deltaSantim, credit.deltaSantim);
        expect(storedCredit.kind, credit.kind);
      },
    );

    test('reverses a payment with the opposite balance delta', () async {
      final customer = await addCustomer();
      await repository.addCredit(customerId: customer.id, amountSantim: 2500);
      final payment = await repository.addPayment(
        customerId: customer.id,
        amountSantim: 1000,
      );

      final reversal = await repository.reverseEntry(entryId: payment.id);

      expect(reversal.deltaSantim, 1000);
      expect(await repository.getOutstandingBalance(customer.id), 2500);
    });

    test('blocks reversal of a reversal and double reversal', () async {
      final customer = await addCustomer();
      final credit = await repository.addCredit(
        customerId: customer.id,
        amountSantim: 1500,
      );
      final reversal = await repository.reverseEntry(entryId: credit.id);

      await expectLater(
        repository.reverseEntry(entryId: reversal.id),
        throwsStateError,
      );
      await expectLater(
        repository.reverseEntry(entryId: credit.id),
        throwsStateError,
      );

      expect(await database.select(database.ledgerEntries).get(), hasLength(2));
      expect(await repository.getOutstandingBalance(customer.id), 0);
    });

    test('rejects reversal of an entry outside this shop', () async {
      final customer = await addCustomer();
      final credit = await repository.addCredit(
        customerId: customer.id,
        amountSantim: 1500,
      );
      final otherShopRepository = LocalLedgerRepository(
        database,
        shopId: 'shop-2',
        deviceId: 'device-2',
      );

      await expectLater(
        otherShopRepository.reverseEntry(entryId: credit.id),
        throwsArgumentError,
      );
      expect(await database.select(database.ledgerEntries).get(), hasLength(1));
    });

    test('updates customer and soft-deletes customer', () async {
      final customer = await addCustomer('Initial Name');
      await repository.updateCustomer(
        customerId: customer.id,
        name: 'Updated Name',
        phone: '0988776655',
        note: 'Updated Note',
      );
      final updated = await repository.getCustomer(customer.id);
      expect(updated?.name, 'Updated Name');
      expect(updated?.phone, '0988776655');
      expect(updated?.note, 'Updated Note');

      await repository.softDeleteCustomer(customer.id);
      final deleted = await repository.getCustomer(customer.id);
      expect(deleted, isNull);
    });

    test(
      'watchAllEntries watches all ledger entries across customers with optional filter',
      () async {
        final first = await addCustomer('Cust A');
        final second = await addCustomer('Cust B');

        await repository.addCredit(customerId: first.id, amountSantim: 1000);
        await repository.addCredit(customerId: second.id, amountSantim: 2000);
        await repository.addPayment(customerId: first.id, amountSantim: 500);

        final all = await repository.watchAllEntries().first;
        expect(all, hasLength(3));

        final paymentsOnly = await repository
            .watchAllEntries(kind: 'payment')
            .first;
        expect(paymentsOnly, hasLength(1));
        expect(paymentsOnly.first.amountSantim, 500);

        final creditsOnly = await repository
            .watchAllEntries(kind: 'credit')
            .first;
        expect(creditsOnly, hasLength(2));
      },
    );
  });
}
