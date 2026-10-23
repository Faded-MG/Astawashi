import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/providers/app_providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/amount_chips.dart';
import '../../../app/widgets/customer_avatar.dart';
import '../../../core/db/app_database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/money/santim.dart';

enum LedgerFilter { all, sales, repayments }

class LedgerScreen extends ConsumerStatefulWidget {
  const LedgerScreen({super.key});

  @override
  ConsumerState<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends ConsumerState<LedgerScreen> {
  LedgerFilter _filter = LedgerFilter.all;

  void _showReversalConfirmation({
    required BuildContext context,
    required LedgerEntry entry,
    required AppLocalizations l10n,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.reverseConfirmTitle),
          content: Text(l10n.reverseConfirmMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  final repo = ref.read(ledgerRepositoryProvider);
                  await repo.reverseEntry(entryId: entry.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.reversalSuccess),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${l10n.error}: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              child: Text(l10n.reverseEntryAction),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final activityAsync = ref.watch(recentActivityProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.ledger),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Pills
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  AmountChip(
                    label: l10n.filterAllTransactions,
                    isSelected: _filter == LedgerFilter.all,
                    onTap: () => setState(() => _filter = LedgerFilter.all),
                  ),
                  const SizedBox(width: 8),
                  AmountChip(
                    label: l10n.filterSales,
                    isSelected: _filter == LedgerFilter.sales,
                    onTap: () => setState(() => _filter = LedgerFilter.sales),
                  ),
                  const SizedBox(width: 8),
                  AmountChip(
                    label: l10n.filterRepayments,
                    isSelected: _filter == LedgerFilter.repayments,
                    onTap: () =>
                        setState(() => _filter = LedgerFilter.repayments),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Transactions Feed
            Expanded(
              child: activityAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('${l10n.error}: $e')),
                data: (items) {
                  final filtered = items.where((item) {
                    if (_filter == LedgerFilter.sales) {
                      return item.entry.kind == 'credit';
                    }
                    if (_filter == LedgerFilter.repayments) {
                      return item.entry.kind == 'payment';
                    }
                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.receipt_long_outlined,
                            size: 48,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.noRecentActivity,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final reversedIds = items
                      .where((item) => item.entry.reversesId != null)
                      .map((item) => item.entry.reversesId!)
                      .toSet();

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final entry = item.entry;
                      final customerName = item.customer?.name ?? 'Customer';
                      final isCredit = entry.kind == 'credit';
                      final isPayment = entry.kind == 'payment';
                      final isReversal = entry.kind == 'reversal';
                      final isReversed = reversedIds.contains(entry.id);

                      final formattedDate = DateFormat(
                        'MMM d, yyyy • h:mm a',
                      ).format(entry.occurredAt.toLocal());
                      final formattedAmount = formatSantimAsBirr(
                        entry.amountSantim,
                        symbol: 'ETB', symbolAtStart: true, useGrouping: true,
                      );

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CustomerAvatar(name: customerName, size: 40),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customerName,
                                        style: AppTypography.bodyMedium
                                            .copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        formattedDate,
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
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
                                        decoration: isReversed
                                            ? TextDecoration.lineThrough
                                            : null,
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
                                          fontWeight: FontWeight.w700,
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
                            if (entry.note != null &&
                                entry.note!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                entry.note!,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                            if (!isReversal && !isReversed) ...[
                              const Divider(height: 18),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(60, 24),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () => _showReversalConfirmation(
                                    context: context,
                                    entry: entry,
                                    l10n: l10n,
                                  ),
                                  child: Text(
                                    l10n.reverseEntryAction,
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            if (isReversed) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.chipBackground,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  l10n.alreadyReversed,
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 10,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
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
