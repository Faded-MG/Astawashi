import 'package:astawash/app/providers/app_providers.dart';
import 'package:astawash/core/db/app_database.dart';
import 'package:astawash/main.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  const testShopId = 'test_shop_primary';

  Widget createTestApp({String initialLocation = '/dashboard'}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        shopIdProvider.overrideWith(
          () => ShopIdNotifier(initialShopId: testShopId),
        ),
        shopNameProvider.overrideWith(
          () => ShopNameNotifier(initialShopName: 'My Kiosk'),
        ),
      ],
      child: MyApp(initialLocation: initialLocation),
    );
  }

  group('Astawash Reference UI', () {
    testWidgets(
      'Dashboard renders total outstanding, quick action buttons, and recent activity',
      (tester) async {
        await tester.pumpWidget(createTestApp(initialLocation: '/dashboard'));
        await tester.pumpAndSettle();

        // Check header and shop name
        expect(find.text('My Kiosk'), findsOneWidget);
        expect(find.text('Total Outstanding'), findsOneWidget);
        expect(find.text('ETB 0.00'), findsOneWidget);

        // Check 3 Quick Action buttons
        expect(find.text('New Credit'), findsOneWidget);
        expect(find.text('Repayment'), findsOneWidget);
        expect(find.text('Add Customer'), findsOneWidget);

        // Check Recent Activity empty state
        expect(find.text('Recent Activity'), findsOneWidget);
        expect(
          find.text('No recent transactions. Record a sale to start.'),
          findsOneWidget,
        );

        // Check Bottom navigation items
        expect(find.text('Dashboard'), findsOneWidget);
        expect(find.text('Customers'), findsOneWidget);
        expect(find.text('Ledger'), findsOneWidget);
        expect(find.text('More'), findsOneWidget);

        // Clean unmount
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 50));
      },
    );

    testWidgets(
      'Add Customer screen adds a customer and shows them in the customers tab',
      (tester) async {
        await tester.pumpWidget(
          createTestApp(initialLocation: '/customers/new'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Add New Customer'), findsOneWidget);

        // Fill form
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'Dawit Alemayehu',
        );
        await tester.enterText(find.byType(TextFormField).at(1), '0911002233');
        await tester.enterText(
          find.byType(TextFormField).at(2),
          'Green kiosk near school',
        );
        await tester.pumpAndSettle();

        // Tap Save
        await tester.tap(find.text('Save Customer'));
        await tester.pumpAndSettle();

        // Verify customer exists in database
        final customers = await database.select(database.customers).get();
        expect(customers.length, 1);
        expect(customers.first.name, 'Dawit Alemayehu');
        expect(customers.first.phone, '0911002233');

        // Clean unmount
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 50));
      },
    );

    testWidgets(
      'New Credit Sale records credit entry and updates total balance',
      (tester) async {
        // First insert a customer
        await database
            .into(database.customers)
            .insert(
              Customer(
                id: 'cust-1',
                shopId: testShopId,
                name: 'Sara Tadesse',
                phone: '0922334455',
                createdAt: DateTime.now().toUtc(),
                updatedAt: DateTime.now().toUtc(),
              ),
            );

        await tester.pumpWidget(
          createTestApp(initialLocation: '/credit/new?customerId=cust-1'),
        );
        await tester.pumpAndSettle();

        expect(find.text('New Credit Sale'), findsOneWidget);

        // Enter amount: 1500 birr
        await tester.enterText(find.byType(TextFormField).at(0), '1500');
        await tester.enterText(find.byType(TextFormField).at(1), '20kg Teff');
        await tester.pumpAndSettle();

        // Save
        await tester.tap(find.text('Save Credit Sale'));
        await tester.pumpAndSettle();

        // Verify entry exists in database
        final entries = await database.select(database.ledgerEntries).get();
        expect(entries.length, 1);
        expect(entries.first.kind, 'credit');
        expect(entries.first.amountSantim, 150000);
        expect(entries.first.deltaSantim, 150000);
        expect(entries.first.note, '20kg Teff');

        // Clean unmount
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 50));
      },
    );

    testWidgets('Record Repayment caps amount to outstanding balance', (
      tester,
    ) async {
      // Insert customer
      await database
          .into(database.customers)
          .insert(
            Customer(
              id: 'cust-2',
              shopId: testShopId,
              name: 'Kebede Haile',
              createdAt: DateTime.now().toUtc(),
              updatedAt: DateTime.now().toUtc(),
            ),
          );

      // Insert credit entry of 500 birr (50,000 santim)
      await database
          .into(database.ledgerEntries)
          .insert(
            LedgerEntry(
              id: 'entry-1',
              shopId: testShopId,
              customerId: 'cust-2',
              kind: 'credit',
              amountSantim: 50000,
              deltaSantim: 50000,
              occurredAt: DateTime.now().toUtc(),
              createdAt: DateTime.now().toUtc(),
              deviceId: 'device_local_primary',
            ),
          );

      await tester.pumpWidget(
        createTestApp(initialLocation: '/repayment/new?customerId=cust-2'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Record Repayment'), findsOneWidget);
      expect(find.text('Current balance: ETB 500.00'), findsOneWidget);

      // Enter repayment of 600 birr (exceeds 500 balance)
      await tester.enterText(find.byType(TextFormField).at(0), '600');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Confirm Repayment'));
      await tester.tap(find.text('Confirm Repayment'));
      await tester.pumpAndSettle();

      // Error message displayed
      expect(
        find.text(
          'Payment amount cannot exceed outstanding balance of ETB 500.00',
        ),
        findsOneWidget,
      );

      // Now enter valid repayment: 200 birr
      await tester.enterText(find.byType(TextFormField).at(0), '200');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Confirm Repayment'));
      await tester.tap(find.text('Confirm Repayment'));
      await tester.pumpAndSettle();

      // Verify payment entry saved
      final entries = await database.select(database.ledgerEntries).get();
      expect(entries.length, 2);
      final payment = entries.firstWhere((e) => e.kind == 'payment');
      expect(payment.amountSantim, 20000);
      expect(payment.deltaSantim, -20000);

      // Clean unmount
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('More screen allows switching language to Amharic', (
      tester,
    ) async {
      await tester.pumpWidget(createTestApp(initialLocation: '/more'));
      await tester.pumpAndSettle();

      expect(find.text('Language'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('አማርኛ (Amharic)'), findsOneWidget);

      // Switch to Amharic
      await tester.tap(find.text('አማርኛ (Amharic)'));
      await tester.pumpAndSettle();

      // Verify Amharic strings appear
      expect(find.text('ቋንቋ'), findsOneWidget);
      expect(find.text('ተጨማሪ'), findsNWidgets(2));

      // Clean unmount
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}
