import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/app_database.dart';
import '../../features/ledger/data/local_ledger_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

class ShopIdNotifier extends Notifier<String> {
  @override
  String build() => 'shop_offline_primary';

  void setShopId(String id) => state = id;
}

final shopIdProvider = NotifierProvider<ShopIdNotifier, String>(
  ShopIdNotifier.new,
);

class ShopNameNotifier extends Notifier<String> {
  @override
  String build() => "Abebe's Kiosk";

  void setShopName(String name) => state = name;
}

final shopNameProvider = NotifierProvider<ShopNameNotifier, String>(
  ShopNameNotifier.new,
);

class DeviceIdNotifier extends Notifier<String> {
  @override
  String build() => 'device_local_primary';

  void setDeviceId(String id) => state = id;
}

final deviceIdProvider = NotifierProvider<DeviceIdNotifier, String>(
  DeviceIdNotifier.new,
);

final ledgerRepositoryProvider = Provider<LocalLedgerRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final shopId = ref.watch(shopIdProvider);
  final deviceId = ref.watch(deviceIdProvider);
  return LocalLedgerRepository(db, shopId: shopId, deviceId: deviceId);
});

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() => const Locale('en');

  void setLocale(Locale locale) => state = locale;

  void toggle() {
    state = state.languageCode == 'en'
        ? const Locale('am')
        : const Locale('en');
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);

final totalOutstandingProvider = StreamProvider<int>((ref) {
  return ref.watch(ledgerRepositoryProvider).watchTotalOutstanding();
});

final customersProvider = StreamProvider<List<Customer>>((ref) {
  return ref.watch(ledgerRepositoryProvider).watchCustomers();
});

final customerBalanceProvider = StreamProvider.family<int, String>((
  ref,
  customerId,
) {
  return ref
      .watch(ledgerRepositoryProvider)
      .watchOutstandingBalance(customerId);
});

final customerHistoryProvider =
    StreamProvider.family<List<LedgerEntry>, String>((ref, customerId) {
      return ref.watch(ledgerRepositoryProvider).watchHistory(customerId);
    });

final allLedgerEntriesProvider = StreamProvider<List<LedgerEntry>>((ref) {
  return ref.watch(ledgerRepositoryProvider).watchAllEntries();
});

class ActivityItem {
  const ActivityItem({required this.entry, this.customer});

  final LedgerEntry entry;
  final Customer? customer;
}

final recentActivityProvider = Provider<AsyncValue<List<ActivityItem>>>((ref) {
  final entriesAsync = ref.watch(allLedgerEntriesProvider);
  final customersAsync = ref.watch(customersProvider);

  if (entriesAsync.isLoading || customersAsync.isLoading) {
    return const AsyncValue.loading();
  }

  if (entriesAsync.hasError) {
    return AsyncValue.error(entriesAsync.error!, entriesAsync.stackTrace!);
  }

  if (customersAsync.hasError) {
    return AsyncValue.error(customersAsync.error!, customersAsync.stackTrace!);
  }

  final customers = customersAsync.value ?? [];
  final customerMap = {for (final c in customers) c.id: c};
  final entries = entriesAsync.value ?? [];

  final items = entries.map((entry) {
    return ActivityItem(entry: entry, customer: customerMap[entry.customerId]);
  }).toList();

  return AsyncValue.data(items);
});
