class SessionTokens {
  const SessionTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.shopId,
  });

  final String accessToken;
  final String refreshToken;
  final String shopId;

  factory SessionTokens.fromJson(Map<String, dynamic> json) {
    final accessToken = json['accessToken'];
    final refreshToken = json['refreshToken'];
    final user = json['user'];
    final shopId = user is Map<String, dynamic> ? user['shopId'] : null;
    if (accessToken is! String ||
        refreshToken is! String ||
        shopId is! String) {
      throw const FormatException(
        'The server returned an invalid token response.',
      );
    }
    return SessionTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      shopId: shopId,
    );
  }
}

class SyncCustomerData {
  const SyncCustomerData({
    required this.id,
    required this.name,
    required this.phone,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
    this.shopId,
    this.serverSeq,
  });

  final String id;
  final String name;
  final String? phone;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? shopId;
  final BigInt? serverSeq;

  factory SyncCustomerData.fromJson(Map<String, dynamic> json) {
    return SyncCustomerData(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      phone: json['phone'] as String?,
      note: json['note'] as String?,
      createdAt: _date(json, 'createdAt'),
      updatedAt: _date(json, 'updatedAt'),
      deletedAt: json['deletedAt'] == null ? null : _date(json, 'deletedAt'),
      shopId: json['shopId'] as String?,
      serverSeq: json['serverSeq'] == null
          ? null
          : BigInt.parse(json['serverSeq'].toString()),
    );
  }

  Map<String, Object?> toPushJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'note': note,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
  };
}

class SyncEntryData {
  const SyncEntryData({
    required this.id,
    required this.customerId,
    required this.kind,
    required this.amountSantim,
    required this.deltaSantim,
    required this.reversesId,
    required this.note,
    required this.occurredAt,
    required this.createdAt,
    required this.deviceId,
    this.shopId,
    this.serverSeq,
  });

  final String id;
  final String customerId;
  final String kind;
  final int amountSantim;
  final int deltaSantim;
  final String? reversesId;
  final String? note;
  final DateTime occurredAt;
  final DateTime createdAt;
  final String deviceId;
  final String? shopId;
  final BigInt? serverSeq;

  factory SyncEntryData.fromJson(Map<String, dynamic> json) {
    final amount = json['amountSantim'];
    final delta = json['deltaSantim'];
    if (amount is! int || delta is! int) {
      throw const FormatException(
        'The server returned non-integer money values.',
      );
    }
    return SyncEntryData(
      id: _requiredString(json, 'id'),
      customerId: _requiredString(json, 'customerId'),
      kind: _requiredString(json, 'kind'),
      amountSantim: amount,
      deltaSantim: delta,
      reversesId: json['reversesId'] as String?,
      note: json['note'] as String?,
      occurredAt: _date(json, 'occurredAt'),
      createdAt: _date(json, 'createdAt'),
      deviceId: _requiredString(json, 'deviceId'),
      shopId: json['shopId'] as String?,
      serverSeq: json['serverSeq'] == null
          ? null
          : BigInt.parse(json['serverSeq'].toString()),
    );
  }

  Map<String, Object?> toPushJson() => {
    'id': id,
    'customerId': customerId,
    'kind': kind,
    'amountSantim': amountSantim,
    'deltaSantim': deltaSantim,
    'reversesId': reversesId,
    'note': note,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'deviceId': deviceId,
  };
}

class PushAcknowledgements {
  const PushAcknowledgements({
    required this.acceptedCustomerIds,
    required this.acceptedEntryIds,
    required this.alreadyAcceptedCustomerIds,
    required this.alreadyAcceptedEntryIds,
    required this.rejectedCustomers,
    required this.rejectedEntries,
  });

  final List<String> acceptedCustomerIds;
  final List<String> acceptedEntryIds;
  final List<String> alreadyAcceptedCustomerIds;
  final List<String> alreadyAcceptedEntryIds;
  final List<RejectedSyncChange> rejectedCustomers;
  final List<RejectedSyncChange> rejectedEntries;

  factory PushAcknowledgements.fromJson(Map<String, dynamic> json) {
    return PushAcknowledgements(
      acceptedCustomerIds: _stringList(json, 'acceptedCustomerIds'),
      acceptedEntryIds: _stringList(json, 'acceptedEntryIds'),
      alreadyAcceptedCustomerIds: _stringList(
        json,
        'alreadyAcceptedCustomerIds',
      ),
      alreadyAcceptedEntryIds: _stringList(json, 'alreadyAcceptedEntryIds'),
      rejectedCustomers: _rejectedList(json, 'rejectedCustomers'),
      rejectedEntries: _rejectedList(json, 'rejectedEntries'),
    );
  }
}

class RejectedSyncChange {
  const RejectedSyncChange({required this.id, required this.reason});

  final String id;
  final String reason;
}

class SyncPullPage {
  const SyncPullPage({
    required this.customers,
    required this.entries,
    required this.hasMore,
    required this.nextCursor,
  });

  final List<SyncCustomerData> customers;
  final List<SyncEntryData> entries;
  final bool hasMore;
  final BigInt? nextCursor;

  factory SyncPullPage.fromJson(Map<String, dynamic> json) {
    final customers = json['customers'];
    final entries = json['entries'];
    final hasMore = json['hasMore'];
    if (customers is! List || entries is! List || hasMore is! bool) {
      throw const FormatException('The server returned an invalid sync page.');
    }
    final cursor = json['nextCursor'];
    return SyncPullPage(
      customers: customers
          .map((row) => SyncCustomerData.fromJson(row as Map<String, dynamic>))
          .toList(growable: false),
      entries: entries
          .map((row) => SyncEntryData.fromJson(row as Map<String, dynamic>))
          .toList(growable: false),
      hasMore: hasMore,
      nextCursor: cursor == null ? null : BigInt.parse(cursor.toString()),
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('The server returned an invalid $key value.');
  }
  return value;
}

DateTime _date(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('The server returned an invalid $key timestamp.');
  }
  return parsed.toUtc();
}

List<String> _stringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('The server returned an invalid $key list.');
  }
  return value.cast<String>();
}

List<RejectedSyncChange> _rejectedList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('The server returned an invalid $key list.');
  }
  return value
      .map((item) {
        if (item is! Map<String, dynamic> ||
            item['id'] is! String ||
            item['reason'] is! String) {
          throw FormatException('The server returned an invalid $key item.');
        }
        return RejectedSyncChange(
          id: item['id'] as String,
          reason: item['reason'] as String,
        );
      })
      .toList(growable: false);
}
