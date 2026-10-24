import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/providers/app_providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/customer_avatar.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/money/santim.dart';
import '../widgets/quick_action_card.dart';

class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final shopName = ref.watch(shopNameProvider);
    final totalOutstandingAsync = ref.watch(totalOutstandingProvider);
    final customersAsync = ref.watch(customersProvider);
    final recentActivityAsync = ref.watch(recentActivityProvider);
    final currentLocale = ref.watch(localeProvider);

    final totalSantim = totalOutstandingAsync.value ?? 0;
    final customers = customersAsync.value ?? [];
    final activeCustomersCount = customers.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(totalOutstandingProvider);
            ref.invalidate(customersProvider);
            ref.invalidate(allLedgerEntriesProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shopName.isNotEmpty ? shopName : l10n.defaultShopName,
                          style: AppTypography.h2.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.defaultShopName,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // Language switcher pill
                        InkWell(
                          onTap: () =>
                              ref.read(localeProvider.notifier).toggle(),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.language,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  currentLocale.languageCode == 'en'
                                      ? 'EN'
                                      : 'አማ',
                                  style: AppTypography.caption.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Sync status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                l10n.syncStatusSynced,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Hero Card: Total Outstanding
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.totalOutstanding,
                            style: AppTypography.bodyMedium.copyWith(
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.people_alt_outlined,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$activeCustomersCount',
                                  style: AppTypography.caption.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      totalOutstandingAsync.isLoading
                          ? const SizedBox(
                              height: 36,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              formatSantimAsBirr(
                                totalSantim,
                                symbol: 'ETB',
                                symbolAtStart: true,
                                useGrouping: true,
                              ),
                              style: AppTypography.amountHero,
                            ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.customersWithBalance(activeCustomersCount),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.sand,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // 3 Quick Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: QuickActionCard(
                        icon: Icons.add_circle_outline_rounded,
                        label: l10n.newCreditSale,
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        onTap: () => context.push('/credit/new'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: QuickActionCard(
                        icon: Icons.payments_outlined,
                        label: l10n.recordRepayment,
                        backgroundColor: AppColors.sand,
                        foregroundColor: AppColors.textOnSand,
                        onTap: () => context.push('/repayment/new'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: QuickActionCard(
                        icon: Icons.person_add_alt_1_outlined,
                        label: l10n.addCustomer,
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.primary,
                        hasBorder: true,
                        onTap: () => context.push('/customers/new'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Recent Activity Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.recentActivity, style: AppTypography.h3),
                    TextButton(
                      onPressed: () => context.go('/ledger'),
                      child: Text(
                        l10n.viewAll,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                recentActivityAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (error, _) => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.errorBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${l10n.error}: $error',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 36,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.receipt_long_outlined,
                              size: 44,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l10n.noRecentActivity,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    final recentItems = items.take(5).toList();
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recentItems.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = recentItems[index];
                        final entry = item.entry;
                        final customerName = item.customer?.name ?? 'Customer';
                        final isCredit = entry.kind == 'credit';
                        final isPayment = entry.kind == 'payment';

                        final formattedDate = DateFormat(
                          'MMM d, h:mm a',
                        ).format(entry.occurredAt.toLocal());
                        final formattedAmount = formatSantimAsBirr(
                          entry.amountSantim,
                          symbol: 'ETB',
                          symbolAtStart: true,
                          useGrouping: true,
                        );

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              CustomerAvatar(name: customerName, size: 42),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customerName,
                                      style: AppTypography.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      entry.note != null &&
                                              entry.note!.isNotEmpty
                                          ? '${entry.note} • $formattedDate'
                                          : formattedDate,
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
                                    isCredit
                                        ? '+ $formattedAmount'
                                        : isPayment
                                        ? '- $formattedAmount'
                                        : '± $formattedAmount',
                                    style: AppTypography.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: isCredit
                                          ? AppColors.textPrimary
                                          : isPayment
                                          ? AppColors.success
                                          : AppColors.warning,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isCredit
                                          ? AppColors.primaryLight.withValues(
                                              alpha: 0.1,
                                            )
                                          : isPayment
                                          ? AppColors.successBackground
                                          : AppColors.warningBackground,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isCredit
                                          ? l10n.transactionCredit
                                          : isPayment
                                          ? l10n.transactionPayment
                                          : l10n.transactionReversal,
                                      style: AppTypography.caption.copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isCredit
                                            ? AppColors.primary
                                            : isPayment
                                            ? AppColors.success
                                            : AppColors.warning,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
