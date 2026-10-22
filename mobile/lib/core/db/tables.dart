// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

/// Customers table in local SQLite database.
///
/// Matches the schema in PLAN.md Section 4.
class Customers extends Table {
  /// Client-generated UUIDv7 primary key.
  TextColumn get id => text()();

  /// UUID of the shop this customer belongs to.
  TextColumn get shopId => text()();

  /// Customer's full name.
  TextColumn get name => text()();

  /// Customer's phone number.
  TextColumn get phone => text().nullable()();

  /// Optional notes about the customer.
  TextColumn get note => text().nullable()();

  /// Creation timestamp.
  DateTimeColumn get createdAt => dateTime()();

  /// Last update timestamp (used for last-write-wins sync).
  DateTimeColumn get updatedAt => dateTime()();

  /// Soft deletion timestamp.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// Local sync timestamp: null indicates local unpushed outbox row.
  DateTimeColumn get syncedAt => dateTime().nullable()();

  /// Server sequence number assigned by pull sync cursor.
  Int64Column get serverSeq => int64().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Ledger entries table in local SQLite database.
///
/// Immutable financial events: append-only ledger.
/// Matches the schema in PLAN.md Section 4.
@TableIndex(
  name: 'idx_ledger_entries_reverses_id',
  columns: {#reversesId},
  unique: true,
)
class LedgerEntries extends Table {
  /// Client-generated UUIDv7 primary key, doubles as idempotency key.
  TextColumn get id => text()();

  /// UUID of the shop this entry belongs to.
  TextColumn get shopId => text()();

  /// Customer foreign key.
  TextColumn get customerId => text().references(Customers, #id)();

  /// Transaction kind: 'credit', 'payment', or 'reversal'.
  TextColumn get kind =>
      text().check(kind.isIn(const ['credit', 'payment', 'reversal']))();

  /// Transaction amount in integer santim (must be strictly > 0).
  IntColumn get amountSantim =>
      integer().check(amountSantim.isBiggerThan(const Constant(0)))();

  /// Balance delta in integer santim (+credit, -payment, reversal = -(original delta)).
  IntColumn get deltaSantim => integer()();

  /// Optional reversal target ID. Points to the ledger entry being reversed.
  /// Enforced unique by [TableIndex] so an entry can only be reversed once.
  TextColumn get reversesId =>
      text().nullable().references(LedgerEntries, #id)();

  /// Optional note explaining the transaction.
  TextColumn get note => text().nullable()();

  /// When the transaction occurred.
  DateTimeColumn get occurredAt => dateTime()();

  /// When the record was created locally.
  DateTimeColumn get createdAt => dateTime()();

  /// Identifier of the device that created this record.
  TextColumn get deviceId => text()();

  /// Local sync timestamp: null indicates unpushed outbox row.
  DateTimeColumn get syncedAt => dateTime().nullable()();

  /// Server sequence number assigned by pull sync cursor.
  Int64Column get serverSeq => int64().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local sync state cursor.
///
/// Stores the highest server sequence number received from pull sync.
/// Matches the schema in PLAN.md Section 4.
class SyncState extends Table {
  /// Single row identifier.
  IntColumn get id => integer().autoIncrement()();

  /// Server sequence number cursor.
  Int64Column get lastPullSeq => int64().nullable()();
}
