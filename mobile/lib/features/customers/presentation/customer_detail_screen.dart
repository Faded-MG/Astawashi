import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/providers/app_providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/action_buttons.dart';
import '../../../app/widgets/customer_avatar.dart';
import '../../../core/db/app_database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/money/santim.dart';

class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.customerId});

  final String customerId;

  Future<void> _makePhoneCall(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _sendSmsReminder({
    required BuildContext context,
    required String phone,
    required String name,
    required int balanceSantim,
    required String shopName,
    required AppLocalizations l10n,
  }) async {
    final formattedAmount = formatSantimAsBirr(balanceSantim);
    final message = l10n.reminderMessage(name, formattedAmount, shopName);
    final uri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {'body': message},
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.error), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showReversalConfirmation({
    required BuildContext context,
    required WidgetRef ref,
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
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final customersAsync = ref.watch(customersProvider);
    final balanceAsync = ref.watch(customerBalanceProvider(customerId));
    final historyAsync = ref.watch(customerHistoryProvider(customerId));
    final shopName = ref.watch(shopNameProvider);

    final customer = customersAsync.value
        ?.where((c) => c.id == customerId)
        .firstOrNull;
    final balanceSantim = balanceAsync.value ?? 0;
    final formattedBalance = formatSantimAsBirr(balanceSantim, symbol: 'ETB', symbolAtStart: true, useGrouping: true);

    if (customer == null && !customersAsync.isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.customerDetail)),
        body: Center(child: Text(l10n.noCustomersFound)),
      );
    }

    final customerPhone = customer?.phone;
    final hasPhone = customerPhone != null && customerPhone.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(customer?.name ?? l10n.customerDetail),
        actions: [
          if (hasPhone) ...[
            IconButton(
              icon: const Icon(Icons.phone_outlined, color: AppColors.primary),
              onPressed: () => _makePhoneCall(customerPhone),
            ),
            IconButton(
              icon: const Icon(Icons.sms_outlined, color: AppColors.primary),
              onPressed: () => _sendSmsReminder(
                context: context,
                phone: customerPhone,
                name: customer?.name ?? '',
                balanceSantim: balanceSantim,
                shopName: shopName,
                l10n: l10n,
              ),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Customer Profile Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    CustomerAvatar(name: customer?.name ?? '', size: 52),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(customer?.name ?? '', style: AppTypography.h2),
                          if (hasPhone) ...[
                            const SizedBox(height: 4),
                            Text(
                              customerPhone,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          if (customer?.note != null &&
                              customer!.note!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              customer.note!,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Current Balance Card
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.currentBalance,
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(formattedBalance, style: AppTypography.amountHero),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(
                              Icons.add_circle_outline,
                              size: 18,
                            ),
                            label: Text(
                              l10n.addCreditAction,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: () => context.push(
                              '/credit/new?customerId=$customerId',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.sand,
                              foregroundColor: AppColors.textOnSand,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.payments_outlined, size: 18),
                            label: Text(
                              l10n.recordPaymentAction,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textOnSand,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: () => context.push(
                              '/repayment/new?customerId=$customerId',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (hasPhone && balanceSantim > 0) ...[
                const SizedBox(height: 16),
                AstawashSecondaryButton(
                  icon: const Icon(
                    Icons.send_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  label: l10n.sendReminder,
                  onPressed: () => _sendSmsReminder(
                    context: context,
                    phone: customerPhone,
                    name: customer?.name ?? '',
                    balanceSantim: balanceSantim,
                    shopName: shopName,
                    l10n: l10n,
                  ),
                ),
              ],
              const SizedBox(height: 28),

              // Transaction History Section
              Text(l10n.transactionHistory, style: AppTypography.h3),
              const SizedBox(height: 12),

              historyAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('${l10n.error}: $e')),
                data: (entries) {
                  if (entries.isEmpty) {
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
                      child: Center(
                        child: Text(
                          l10n.noTransactionsCustomer,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  // Find which entries have reversals targeting them
                  final reversedIds = entries
                      .where((e) => e.reversesId != null)
                      .map((e) => e.reversesId!)
                      .toSet();

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
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
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isCredit
                                          ? Icons.arrow_upward_rounded
                                          : isPayment
                                          ? Icons.arrow_downward_rounded
                                          : Icons.undo_rounded,
                                      size: 18,
                                      color: isCredit
                                          ? AppColors.primary
                                          : isPayment
                                          ? AppColors.success
                                          : AppColors.warning,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isCredit
                                          ? l10n.transactionCredit
                                          : isPayment
                                          ? l10n.transactionPayment
                                          : l10n.transactionReversal,
                                      style: AppTypography.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
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
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (entry.note != null &&
                                          entry.note!.isNotEmpty) ...[
                                        Text(
                                          entry.note!,
                                          style: AppTypography.caption.copyWith(
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                      ],
                                      Text(
                                        formattedDate,
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isReversal && !isReversed)
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.error,
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(50, 30),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () => _showReversalConfirmation(
                                      context: context,
                                      ref: ref,
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
                                if (isReversed)
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
    );
  }
}
