import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers/app_providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/action_buttons.dart';
import '../../../app/widgets/amount_chips.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/money/santim.dart';

enum PaymentMethod { cash, digital }

class RecordRepaymentScreen extends ConsumerStatefulWidget {
  const RecordRepaymentScreen({super.key, this.initialCustomerId});

  final String? initialCustomerId;

  @override
  ConsumerState<RecordRepaymentScreen> createState() =>
      _RecordRepaymentScreenState();
}

class _RecordRepaymentScreenState extends ConsumerState<RecordRepaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedCustomerId;
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedCustomerId = widget.initialCustomerId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _addQuickAmount(int birr) {
    final currentSantim = tryParseBirrToSantim(_amountController.text) ?? 0;
    final newSantim = currentSantim + (birr * 100);
    _amountController.text = formatSantimAsBirr(newSantim);
    setState(() {});
  }

  void _setFullBalance(int balanceSantim) {
    _amountController.text = formatSantimAsBirr(balanceSantim);
    setState(() {});
  }

  Future<void> _onConfirm(int currentBalanceSantim) async {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.chooseCustomerHint),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final santim = tryParseBirrToSantim(_amountController.text);
    if (santim == null || santim <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.invalidAmount),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (santim > currentBalanceSantim) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.amountExceedsBalance(
              formatSantimAsBirr(
                currentBalanceSantim,
                symbol: 'ETB',
                symbolAtStart: true,
                useGrouping: true,
              ),
            ),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final methodPrefix = _paymentMethod == PaymentMethod.digital
          ? '[Digital] '
          : '[Cash] ';
      final noteText = _noteController.text.trim();
      final fullNote = noteText.isNotEmpty
          ? '$methodPrefix$noteText'
          : methodPrefix.trim();

      final repo = ref.read(ledgerRepositoryProvider);
      await repo.addPayment(
        customerId: _selectedCustomerId!,
        amountSantim: santim,
        note: fullNote,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.repaymentSuccess),
            backgroundColor: AppColors.primary,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.error}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final customersAsync = ref.watch(customersProvider);
    final customers = customersAsync.value ?? [];

    final balanceAsync = _selectedCustomerId != null
        ? ref.watch(customerBalanceProvider(_selectedCustomerId!))
        : null;
    final balanceSantim = balanceAsync?.value ?? 0;
    final formattedBalance = formatSantimAsBirr(
      balanceSantim,
      symbol: 'ETB',
      symbolAtStart: true,
      useGrouping: true,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.recordRepaymentTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Customer Selector
                Text(
                  l10n.selectCustomer,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCustomerId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    hintText: l10n.chooseCustomerHint,
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  items: [
                    for (final customer in customers)
                      DropdownMenuItem<String>(
                        value: customer.id,
                        child: Text(
                          customer.name,
                          style: AppTypography.bodyMedium,
                        ),
                      ),
                  ],
                  onChanged: (val) => setState(() => _selectedCustomerId = val),
                  validator: (val) =>
                      val == null ? l10n.chooseCustomerHint : null,
                ),

                if (_selectedCustomerId != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.currentDebtNotice(formattedBalance),
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (balanceSantim > 0)
                          InkWell(
                            onTap: () => _setFullBalance(balanceSantim),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.sandLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                l10n.fullBalanceChip,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textOnSand,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Amount Field
                Text(
                  l10n.paymentAmount,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: AppTypography.amountLarge.copyWith(
                    color: AppColors.success,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  decoration: InputDecoration(
                    hintText: l10n.amountPlaceholder,
                    prefixIcon: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Text(
                        l10n.etb,
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ),
                  validator: (value) {
                    final santim = tryParseBirrToSantim(value);
                    if (santim == null || santim <= 0) {
                      return l10n.invalidAmount;
                    }
                    if (_selectedCustomerId != null && santim > balanceSantim) {
                      return l10n.amountExceedsBalance(
                        formatSantimAsBirr(
                          balanceSantim,
                          symbol: 'ETB',
                          symbolAtStart: true,
                          useGrouping: true,
                        ),
                      );
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Quick Increment Chips (+100, +200, +500)
                AmountChipRow(
                  amounts: const [100, 200, 500],
                  onSelected: _addQuickAmount,
                  customTrailingChip: balanceSantim > 0
                      ? AmountChip(
                          label: l10n.fullBalanceChip,
                          onTap: () => _setFullBalance(balanceSantim),
                        )
                      : null,
                ),
                const SizedBox(height: 24),

                // Payment Method Selector
                Text(
                  l10n.paymentMethod,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () =>
                            setState(() => _paymentMethod = PaymentMethod.cash),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _paymentMethod == PaymentMethod.cash
                                ? AppColors.primary
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _paymentMethod == PaymentMethod.cash
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.money_rounded,
                                size: 20,
                                color: _paymentMethod == PaymentMethod.cash
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                l10n.methodCash,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: _paymentMethod == PaymentMethod.cash
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(
                          () => _paymentMethod = PaymentMethod.digital,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _paymentMethod == PaymentMethod.digital
                                ? AppColors.primary
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _paymentMethod == PaymentMethod.digital
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.phone_android_rounded,
                                size: 20,
                                color: _paymentMethod == PaymentMethod.digital
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                l10n.methodDigital,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: _paymentMethod == PaymentMethod.digital
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.digitalMethodNotice,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 20),

                // Note / Reference Field
                Text(
                  l10n.repaymentNote,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: l10n.repaymentNoteHint,
                    prefixIcon: const Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 36),

                // Confirm Button
                AstawashPrimaryButton(
                  label: l10n.confirmRepayment,
                  isLoading: _isSaving,
                  backgroundColor: AppColors.success,
                  onPressed: () => _onConfirm(balanceSantim),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
