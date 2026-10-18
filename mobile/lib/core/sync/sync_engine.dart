import 'package:astawash/core/db/app_database.dart';
import 'package:drift/drift.dart';

import 'sync_api.dart';
import 'sync_models.dart';

class SyncEngine {
  SyncEngine({
    required this._database,
    required this._api,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const _batchLimit = 200;

  final AppDatabase _database;
  final SyncApi _api;
  final DateTime Function() _clock;
  bool _isRunning = false;

  Future<SyncReport> synchronize({int pageSize = 100}) async {
    if (_isRunning) {
      throw StateError('A synchronization is already in progress.');
    }
    if (pageSize < 1 || pageSize > 200) {
      throw ArgumentError.value(pageSize, 'pageSize', 'Must be from 1 to 200.');
    }

    _isRunning = true;
    try {
      final pushed = await _pushPendingChanges();
      final pulled = await _pullChanges(pageSize);
      return SyncReport(
        customersPushed: pushed.customers,
        entriesPushed: pushed.entries,
        customersPulled: pulled.customers,
        entriesPulled: pulled.entries,
      );
    } finally {
      _isRunning = false;
    }
  }

  Future<_PushCounts> _pushPendingChanges() async {
    var pushedCustomers = 0;
    var pushedEntries = 0;

    while (true) {
      final pendingCustomers =
          await (_database.select(_database.customers)
                ..where(
                  (customer) =>
                      customer.shopId.equals(_api.shopId) &
                      customer.syncedAt.isNull(),
                )
                ..orderBy([
                  (customer) => OrderingTerm.asc(customer.createdAt),
                  (customer) => OrderingTerm.asc(customer.id),
                ])
                ..limit(_batchLimit))
              .get();
      final customerCount = pendingCustomers.length;
      final pendingEntries =
          await (_database.select(_database.ledgerEntries)
                ..where(
                  (entry) =>
                      entry.shopId.equals(_api.shopId) &
                      entry.syncedAt.isNull(),
                )
                ..orderBy([
                  (entry) => OrderingTerm.asc(entry.createdAt),
                  (entry) => OrderingTerm.asc(entry.id),
                ])
                ..limit(_batchLimit - customerCount))
              .get();

      if (customerCount == 0 && pendingEntries.isEmpty) {
        return _PushCounts(pushedCustomers, pushedEntries);
      }

      final customers = pendingCustomers.map(_customerData).toList();
      final entries = pendingEntries.map(_entryData).toList();
      final acknowledgement = await _api.push(
        customers: customers,
        entries: entries,
      );
      final acknowledgedCustomerIds = {
        ...acknowledgement.acceptedCustomerIds,
        ...acknowledgement.alreadyAcceptedCustomerIds,
      };
      final acknowledgedEntryIds = {
        ...acknowledgement.acceptedEntryIds,
        ...acknowledgement.alreadyAcceptedEntryIds,
      };
      _validateAcknowledgements(
        customers: customers,
        entries: entries,
        acknowledgements: acknowledgement,
        acknowledgedCustomerIds: acknowledgedCustomerIds,
        acknowledgedEntryIds: acknowledgedEntryIds,
      );

      final syncTime = _clock().toUtc();
      await _database.transaction(() async {
        for (final customer in pendingCustomers) {
          if (acknowledgedCustomerIds.contains(customer.id)) {
            await (_database.update(_database.customers)..where(
                  (row) =>
                      row.id.equals(customer.id) &
                      row.shopId.equals(_api.shopId) &
                      row.updatedAt.equals(customer.updatedAt),
                ))
                .write(CustomersCompanion(syncedAt: Value(syncTime)));
          }
        }
        for (final entry in pendingEntries) {
          if (acknowledgedEntryIds.contains(entry.id)) {
            await (_database.update(_database.ledgerEntries)..where(
                  (row) =>
                      row.id.equals(entry.id) &
                      row.shopId.equals(_api.shopId) &
                      row.syncedAt.isNull(),
                ))
                .write(LedgerEntriesCompanion(syncedAt: Value(syncTime)));
          }
        }
      });

      pushedCustomers += acknowledgedCustomerIds.length;
      pushedEntries += acknowledgedEntryIds.length;

      if (acknowledgement.rejectedCustomers.isNotEmpty ||
          acknowledgement.rejectedEntries.isNotEmpty) {
        throw SyncRejectedChangesException(
          customers: acknowledgement.rejectedCustomers,
          entries: acknowledgement.rejectedEntries,
        );
      }
      if (acknowledgedCustomerIds.length != customers.length ||
          acknowledgedEntryIds.length != entries.length) {
        throw const SyncProtocolException(
          'The server did not acknowledge every submitted change.',
        );
      }
    }
  }

  Future<_PullCounts> _pullChanges(int pageSize) async {
    var pulledCustomers = 0;
    var pulledEntries = 0;
    var cursor = await _readCursor();

    while (true) {
      final page = await _api.pull(since: cursor, limit: pageSize);
      final pageCount = page.customers.length + page.entries.length;
      if (pageCount > pageSize) {
        throw const SyncProtocolException(
          'The server returned more changes than the requested page size.',
        );
      }
      if (pageCount == 0) {
        if (page.hasMore) {
          throw const SyncProtocolException(
            'The server reported more changes without returning a cursor page.',
          );
        }
        return _PullCounts(pulledCustomers, pulledEntries);
      }

      final nextCursor = page.nextCursor;
      if (nextCursor == null || nextCursor <= cursor) {
        throw const SyncProtocolException(
          'The server returned a missing or non-advancing sync cursor.',
        );
      }
      for (final customer in page.customers) {
        if (customer.shopId != _api.shopId ||
            customer.serverSeq == null ||
            customer.serverSeq! <= cursor ||
            customer.serverSeq! > nextCursor) {
          throw const SyncProtocolException(
            'The server returned a customer outside the requested shop or cursor range.',
          );
        }
      }
      for (final entry in page.entries) {
        if (entry.shopId != _api.shopId ||
            entry.serverSeq == null ||
            entry.serverSeq! <= cursor ||
            entry.serverSeq! > nextCursor) {
          throw const SyncProtocolException(
            'The server returned an entry outside the requested shop or cursor range.',
          );
        }
      }

      await _database.transaction(() async {
        for (final customer in page.customers) {
          await _applyCustomer(customer);
        }
        for (final entry in page.entries) {
          await _applyEntry(entry);
        }
        await _database
            .into(_database.syncState)
            .insertOnConflictUpdate(
              SyncStateCompanion(
                id: const Value(1),
                lastPullSeq: Value(nextCursor),
              ),
            );
      });

      cursor = nextCursor;
      pulledCustomers += page.customers.length;
      pulledEntries += page.entries.length;
      if (!page.hasMore) {
        return _PullCounts(pulledCustomers, pulledEntries);
      }
    }
  }

  Future<void> _applyCustomer(SyncCustomerData remote) async {
    final existing = await (_database.select(
      _database.customers,
    )..where((row) => row.id.equals(remote.id))).getSingleOrNull();
    if (existing != null && existing.shopId != _api.shopId) {
      throw SyncConflictException(
        'Customer ${remote.id} is already assigned to a different local shop.',
      );
    }
    if (existing != null && existing.syncedAt == null) {
      return;
    }
    if (existing != null &&
        existing.serverSeq != null &&
        remote.serverSeq! <= existing.serverSeq!) {
      return;
    }
    await _database
        .into(_database.customers)
        .insertOnConflictUpdate(
          CustomersCompanion.insert(
            id: remote.id,
            shopId: _api.shopId,
            name: remote.name,
            phone: Value(remote.phone),
            note: Value(remote.note),
            createdAt: remote.createdAt,
            updatedAt: remote.updatedAt,
            deletedAt: Value(remote.deletedAt),
            syncedAt: Value(_clock().toUtc()),
            serverSeq: Value(remote.serverSeq),
          ),
        );
  }

  Future<void> _applyEntry(SyncEntryData remote) async {
    final existing = await (_database.select(
      _database.ledgerEntries,
    )..where((row) => row.id.equals(remote.id))).getSingleOrNull();
    if (existing != null) {
      final sameContent =
          existing.shopId == _api.shopId &&
          existing.customerId == remote.customerId &&
          existing.kind == remote.kind &&
          existing.amountSantim == remote.amountSantim &&
          existing.deltaSantim == remote.deltaSantim &&
          existing.reversesId == remote.reversesId &&
          existing.note == remote.note &&
          existing.occurredAt.toUtc() == remote.occurredAt.toUtc() &&
          existing.createdAt.toUtc() == remote.createdAt.toUtc() &&
          existing.deviceId == remote.deviceId;
      if (!sameContent) {
        throw SyncConflictException(
          'Ledger entry ${remote.id} has conflicting immutable content.',
        );
      }
      if (existing.syncedAt == null || existing.serverSeq != remote.serverSeq) {
        await (_database.update(
          _database.ledgerEntries,
        )..where((row) => row.id.equals(remote.id))).write(
          LedgerEntriesCompanion(
            syncedAt: Value(_clock().toUtc()),
            serverSeq: Value(remote.serverSeq),
          ),
        );
      }
      return;
    }

    final localCustomer = await (_database.select(
      _database.customers,
    )..where((row) => row.id.equals(remote.customerId))).getSingleOrNull();
    if (localCustomer == null || localCustomer.shopId != _api.shopId) {
      throw SyncConflictException(
        'Ledger entry ${remote.id} refers to a customer not present in this shop.',
      );
    }

    await _database
        .into(_database.ledgerEntries)
        .insert(
          LedgerEntriesCompanion.insert(
            id: remote.id,
            shopId: _api.shopId,
            customerId: remote.customerId,
            kind: remote.kind,
            amountSantim: remote.amountSantim,
            deltaSantim: remote.deltaSantim,
            reversesId: Value(remote.reversesId),
            note: Value(remote.note),
            occurredAt: remote.occurredAt,
            createdAt: remote.createdAt,
            deviceId: remote.deviceId,
            syncedAt: Value(_clock().toUtc()),
            serverSeq: Value(remote.serverSeq),
          ),
        );
  }

  Future<BigInt> _readCursor() async {
    final state = await (_database.select(
      _database.syncState,
    )..where((row) => row.id.equals(1))).getSingleOrNull();
    return state?.lastPullSeq ?? BigInt.zero;
  }

  void _validateAcknowledgements({
    required List<SyncCustomerData> customers,
    required List<SyncEntryData> entries,
    required PushAcknowledgements acknowledgements,
    required Set<String> acknowledgedCustomerIds,
    required Set<String> acknowledgedEntryIds,
  }) {
    final submittedCustomerIds = customers.map((change) => change.id).toSet();
    final submittedEntryIds = entries.map((change) => change.id).toSet();
    final rejectedCustomerIds = acknowledgements.rejectedCustomers
        .map((change) => change.id)
        .toSet();
    final rejectedEntryIds = acknowledgements.rejectedEntries
        .map((change) => change.id)
        .toSet();
    if (!submittedCustomerIds.containsAll(acknowledgedCustomerIds) ||
        !submittedEntryIds.containsAll(acknowledgedEntryIds) ||
        !submittedCustomerIds.containsAll(rejectedCustomerIds) ||
        !submittedEntryIds.containsAll(rejectedEntryIds) ||
        acknowledgedCustomerIds.intersection(rejectedCustomerIds).isNotEmpty ||
        acknowledgedEntryIds.intersection(rejectedEntryIds).isNotEmpty) {
      throw const SyncProtocolException(
        'The server returned acknowledgements for unexpected or conflicting changes.',
      );
    }
  }

  SyncCustomerData _customerData(Customer customer) => SyncCustomerData(
    id: customer.id,
    name: customer.name,
    phone: customer.phone,
    note: customer.note,
    createdAt: customer.createdAt,
    updatedAt: customer.updatedAt,
    deletedAt: customer.deletedAt,
  );

  SyncEntryData _entryData(LedgerEntry entry) => SyncEntryData(
    id: entry.id,
    customerId: entry.customerId,
    kind: entry.kind,
    amountSantim: entry.amountSantim,
    deltaSantim: entry.deltaSantim,
    reversesId: entry.reversesId,
    note: entry.note,
    occurredAt: entry.occurredAt,
    createdAt: entry.createdAt,
    deviceId: entry.deviceId,
  );
}

class SyncReport {
  const SyncReport({
    required this.customersPushed,
    required this.entriesPushed,
    required this.customersPulled,
    required this.entriesPulled,
  });

  final int customersPushed;
  final int entriesPushed;
  final int customersPulled;
  final int entriesPulled;
}

class SyncRejectedChangesException implements Exception {
  const SyncRejectedChangesException({
    required this.customers,
    required this.entries,
  });

  final List<RejectedSyncChange> customers;
  final List<RejectedSyncChange> entries;

  @override
  String toString() =>
      'Sync rejected ${customers.length} customer and ${entries.length} ledger changes.';
}

class SyncConflictException implements Exception {
  const SyncConflictException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SyncProtocolException implements Exception {
  const SyncProtocolException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _PushCounts {
  const _PushCounts(this.customers, this.entries);

  final int customers;
  final int entries;
}

class _PullCounts {
  const _PullCounts(this.customers, this.entries);

  final int customers;
  final int entries;
}
