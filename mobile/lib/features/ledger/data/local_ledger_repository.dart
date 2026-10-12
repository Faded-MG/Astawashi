import 'package:astawash/core/db/app_database.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Local, offline-first application interface for customers and ledger entries.
final class LocalLedgerRepository {
  LocalLedgerRepository(
    this._database, {
    required this.shopId,
    required this.deviceId,
    String Function()? idGenerator,
    DateTime Function()? clock,
  }) : _idGenerator = idGenerator ?? _generateUuidV7,
       _clock = clock ?? DateTime.now;

  final AppDatabase _database;
  final String shopId;
  final String deviceId;
  final String Function() _idGenerator;
  final DateTime Function() _clock;

  /// Adds and returns a customer belonging to this repository's shop.
  Future<Customer> addCustomer({
    required String name,
    String? phone,
    String? note,
  }) async {
    final now = _now();
    final customer = Customer(
      id: _idGenerator(),
      shopId: shopId,
      name: name,
      phone: phone,
      note: note,
      createdAt: now,
      updatedAt: now,
    );

    await _database.into(_database.customers).insert(customer);
    return customer;
  }

  /// Returns an active customer in this shop, or `null` when it is not found.
  Future<Customer?> getCustomer(String customerId) {
    return (_database.select(_database.customers)..where(
          (customer) =>
              customer.id.equals(customerId) &
              customer.shopId.equals(shopId) &
              customer.deletedAt.isNull(),
        ))
        .getSingleOrNull();
  }

  /// Watches active customers in this shop.
  Stream<List<Customer>> watchCustomers() {
    return (_database.select(_database.customers)
          ..where(
            (customer) =>
                customer.shopId.equals(shopId) & customer.deletedAt.isNull(),
          )
          ..orderBy([
            (customer) => OrderingTerm.asc(customer.name),
            (customer) => OrderingTerm.asc(customer.createdAt),
          ]))
        .watch();
  }

  /// Returns the active balance derived from the customer's ledger deltas.
  Future<int> getOutstandingBalance(String customerId) async {
    final row = await _balanceStatement(customerId).getSingleOrNull();
    if (row == null) {
      return 0;
    }
    return row.read<int>('balance_santim');
  }

  /// Alias for [getOutstandingBalance].
  Future<int> getBalance(String customerId) => getOutstandingBalance(customerId);

  /// Watches the balance derived from the customer's ledger deltas.
  Stream<int> watchOutstandingBalance(String customerId) {
    return _balanceStatement(customerId).watchSingleOrNull().map(
      (row) => row?.read<int>('balance_santim') ?? 0,
    );
  }

  /// Alias for [watchOutstandingBalance].
  Stream<int> watchBalance(String customerId) => watchOutstandingBalance(customerId);

  /// Returns the summed outstanding balance for all active customers in this shop.
  Future<int> getTotalOutstanding() async {
    final row = await _totalOutstandingStatement().getSingleOrNull();
    if (row == null) {
      return 0;
    }
    return row.read<int>('total_outstanding_santim');
  }

  /// Watches the summed outstanding balance for all active customers in this shop.
  Stream<int> watchTotalOutstanding() {
    return _totalOutstandingStatement().watchSingleOrNull().map(
      (row) => row?.read<int>('total_outstanding_santim') ?? 0,
    );
  }

  /// Adds a credit sale and returns its immutable ledger entry.
  Future<LedgerEntry> addCredit({
    required String customerId,
    required int amountSantim,
    String? note,
    DateTime? occurredAt,
  }) async {
    _validatePositiveAmount(amountSantim);
    await _requireActiveCustomer(customerId);

    final createdAt = _now();
    final entry = LedgerEntry(
      id: _idGenerator(),
      shopId: shopId,
      customerId: customerId,
      kind: 'credit',
      amountSantim: amountSantim,
      deltaSantim: amountSantim,
      note: note,
      occurredAt: (occurredAt ?? createdAt).toUtc(),
      createdAt: createdAt,
      deviceId: deviceId,
    );

    await _database.into(_database.ledgerEntries).insert(entry);
    return entry;
  }

  /// Adds a repayment if it does not exceed the current outstanding balance.
  Future<LedgerEntry> addPayment({
    required String customerId,
    required int amountSantim,
    String? note,
    DateTime? occurredAt,
  }) async {
    _validatePositiveAmount(amountSantim);

    return _database.transaction(() async {
      await _requireActiveCustomer(customerId);
      final balance = await getOutstandingBalance(customerId);
      if (amountSantim > balance) {
        throw StateError(
          'Repayment of $amountSantim santim exceeds the outstanding '
          'balance of $balance santim.',
        );
      }

      final createdAt = _now();
      final entry = LedgerEntry(
        id: _idGenerator(),
        shopId: shopId,
        customerId: customerId,
        kind: 'payment',
        amountSantim: amountSantim,
        deltaSantim: -amountSantim,
        note: note,
        occurredAt: (occurredAt ?? createdAt).toUtc(),
        createdAt: createdAt,
        deviceId: deviceId,
      );

      await _database.into(_database.ledgerEntries).insert(entry);
      return entry;
    });
  }

  /// Adds a reversal entry without modifying its original ledger entry.
  Future<LedgerEntry> reverseEntry({
    required String entryId,
    String? note,
    DateTime? occurredAt,
  }) {
    return _database.transaction(() async {
      final original =
          await (_database.select(_database.ledgerEntries)..where(
                (entry) =>
                    entry.id.equals(entryId) & entry.shopId.equals(shopId),
              ))
              .getSingleOrNull();
      if (original == null) {
        throw ArgumentError.value(
          entryId,
          'entryId',
          'No ledger entry with this ID exists in this shop.',
        );
      }
      if (original.kind == 'reversal') {
        throw StateError('A reversal entry cannot itself be reversed.');
      }

      final existingReversal =
          await (_database.select(_database.ledgerEntries)
                ..where((entry) => entry.reversesId.equals(original.id)))
              .getSingleOrNull();
      if (existingReversal != null) {
        throw StateError('This ledger entry has already been reversed.');
      }

      final createdAt = _now();
      final reversal = LedgerEntry(
        id: _idGenerator(),
        shopId: shopId,
        customerId: original.customerId,
        kind: 'reversal',
        amountSantim: original.amountSantim,
        deltaSantim: -original.deltaSantim,
        reversesId: original.id,
        note: note,
        occurredAt: (occurredAt ?? createdAt).toUtc(),
        createdAt: createdAt,
        deviceId: deviceId,
      );

      await _database.into(_database.ledgerEntries).insert(reversal);
      return reversal;
    });
  }

  /// Watches a customer's ledger entries in reverse chronological order.
  Stream<List<LedgerEntry>> watchHistory(String customerId) {
    return (_database.select(_database.ledgerEntries)
          ..where(
            (entry) =>
                entry.customerId.equals(customerId) &
                entry.shopId.equals(shopId),
          )
          ..orderBy([
            (entry) => OrderingTerm.desc(entry.occurredAt),
            (entry) => OrderingTerm.desc(entry.createdAt),
            (entry) => OrderingTerm.desc(entry.id),
          ]))
        .watch();
  }

  Future<Customer> _requireActiveCustomer(String customerId) async {
    final customer = await getCustomer(customerId);
    if (customer == null) {
      throw ArgumentError.value(
        customerId,
        'customerId',
        'No active customer with this ID exists in this shop.',
      );
    }
    return customer;
  }

  Selectable<QueryRow> _balanceStatement(String customerId) {
    return _database.customSelect(
      'SELECT COALESCE(SUM(l.delta_santim), 0) AS balance_santim '
      'FROM ledger_entries AS l '
      'INNER JOIN customers AS c ON c.id = l.customer_id AND c.shop_id = l.shop_id '
      'WHERE l.shop_id = ? AND l.customer_id = ? AND c.deleted_at IS NULL',
      variables: [Variable<String>(shopId), Variable<String>(customerId)],
      readsFrom: {_database.ledgerEntries, _database.customers},
    );
  }

  Selectable<QueryRow> _totalOutstandingStatement() {
    return _database.customSelect(
      'SELECT COALESCE(SUM(l.delta_santim), 0) AS total_outstanding_santim '
      'FROM ledger_entries AS l '
      'INNER JOIN customers AS c ON c.id = l.customer_id AND c.shop_id = l.shop_id '
      'WHERE l.shop_id = ? AND c.deleted_at IS NULL',
      variables: [Variable<String>(shopId)],
      readsFrom: {_database.ledgerEntries, _database.customers},
    );
  }

  DateTime _now() => _clock().toUtc();

  static void _validatePositiveAmount(int amountSantim) {
    if (amountSantim <= 0) {
      throw ArgumentError.value(
        amountSantim,
        'amountSantim',
        'Transaction amounts must be greater than zero.',
      );
    }
  }

  static String _generateUuidV7() => Uuid().v7();
}
