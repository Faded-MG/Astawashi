import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers/app_providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/amount_chips.dart';
import '../../../app/widgets/customer_avatar.dart';
import '../../../core/db/app_database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/money/santim.dart';

enum CustomerFilter { all, withBalance, settled }

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchController = TextEditingController();
  CustomerFilter _selectedFilter = CustomerFilter.all;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final customersAsync = ref.watch(customersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.customers),
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/customers/new'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(
          l10n.addCustomer,
          style: AppTypography.bodyMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 8.0,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) =>
                    setState(() => _searchQuery = value.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: l10n.searchCustomersHint,
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textSecondary,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
              ),
            ),

            // Filter Tabs (All / With Balance / Settled)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  AmountChip(
                    label: l10n.filterAll,
                    isSelected: _selectedFilter == CustomerFilter.all,
                    onTap: () =>
                        setState(() => _selectedFilter = CustomerFilter.all),
                  ),
                  const SizedBox(width: 8),
                  AmountChip(
                    label: l10n.filterWithBalance,
                    isSelected: _selectedFilter == CustomerFilter.withBalance,
                    onTap: () => setState(
                      () => _selectedFilter = CustomerFilter.withBalance,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AmountChip(
                    label: l10n.filterSettled,
                    isSelected: _selectedFilter == CustomerFilter.settled,
                    onTap: () => setState(
                      () => _selectedFilter = CustomerFilter.settled,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Customers List
            Expanded(
              child: customersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('${l10n.error}: $e')),
                data: (customers) {
                  final filtered = customers.where((c) {
                    if (_searchQuery.isNotEmpty) {
                      final nameMatch = c.name.toLowerCase().contains(
                        _searchQuery,
                      );
                      final phoneMatch =
                          c.phone?.toLowerCase().contains(_searchQuery) ??
                          false;
                      if (!nameMatch && !phoneMatch) return false;
                    }
                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.people_outline,
                            size: 48,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.noCustomersFound,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.only(
                      left: 20,
                      right: 20,
                      bottom: 84,
                      top: 4,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final customer = filtered[index];
                      return _CustomerListTile(
                        customer: customer,
                        filter: _selectedFilter,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerListTile extends ConsumerWidget {
  const _CustomerListTile({required this.customer, required this.filter});

  final Customer customer;
  final CustomerFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final balanceAsync = ref.watch(customerBalanceProvider(customer.id));

    final balanceSantim = balanceAsync.value ?? 0;

    // Check filter criteria
    if (filter == CustomerFilter.withBalance && balanceSantim <= 0) {
      return const SizedBox.shrink();
    }
    if (filter == CustomerFilter.settled && balanceSantim > 0) {
      return const SizedBox.shrink();
    }

    final hasBalance = balanceSantim > 0;
    final formattedBalance = formatSantimAsBirr(
      balanceSantim,
      symbol: 'ETB',
      symbolAtStart: true,
      useGrouping: true,
    );

    return InkWell(
      onTap: () => context.push('/customers/${customer.id}'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CustomerAvatar(name: customer.name, size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    customer.phone ?? customer.note ?? l10n.owesLabel,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formattedBalance,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: hasBalance
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: hasBalance
                        ? AppColors.warningBackground
                        : AppColors.successBackground,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    hasBalance ? l10n.owesLabel : l10n.settledLabel,
                    style: AppTypography.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: hasBalance ? AppColors.warning : AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
