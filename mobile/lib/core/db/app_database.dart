import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// The central local SQLite database for Astawash.
///
/// Implements the data model and invariants defined in PLAN.md Section 4.
@DriftDatabase(tables: [Customers, LedgerEntries, SyncState])
class AppDatabase extends _$AppDatabase {
  /// Creates an [AppDatabase] instance.
  ///
  /// For production usage, omit [executor] to connect to the persistent
  /// on-device SQLite database.
  /// For tests, pass an in-memory executor such as `NativeDatabase.memory()`.
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();

      // Enforce append-only invariant on ledger_entries at database level:
      // 1. Completely prohibit DELETE operations.
      await customStatement('''
            CREATE TRIGGER prevent_ledger_entries_delete
            BEFORE DELETE ON ledger_entries
            BEGIN
              SELECT RAISE(ABORT, 'ledger_entries is append-only: deletes are prohibited');
            END;
          ''');

      // 2. Prohibit UPDATE operations on financial and audit columns.
      // Allows only sync metadata updates (synced_at, server_seq).
      await customStatement('''
            CREATE TRIGGER prevent_ledger_entries_financial_update
            BEFORE UPDATE ON ledger_entries
            WHEN (
              OLD.id != NEW.id OR
              OLD.shop_id != NEW.shop_id OR
              OLD.customer_id != NEW.customer_id OR
              OLD.kind != NEW.kind OR
              OLD.amount_santim != NEW.amount_santim OR
              OLD.delta_santim != NEW.delta_santim OR
              OLD.reverses_id IS NOT NEW.reverses_id OR
              OLD.note IS NOT NEW.note OR
              OLD.occurred_at != NEW.occurred_at OR
              OLD.created_at != NEW.created_at OR
              OLD.device_id != NEW.device_id
            )
            BEGIN
              SELECT RAISE(ABORT, 'ledger_entries is append-only: financial and audit columns cannot be modified');
            END;
          ''');
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(syncState, syncState.activeShopId);
      }
    },
    beforeOpen: (details) async {
      // Enforce foreign key constraints in SQLite.
      await customStatement('PRAGMA foreign_keys = ON;');
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'astawash.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
