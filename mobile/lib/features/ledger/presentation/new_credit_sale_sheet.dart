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

class NewCreditSaleScreen extends ConsumerStatefulWidget {
  const NewCreditSaleScreen({super.key, this.initialCustomerId});

  final String? initialCustomerId;

  @override
  ConsumerState<NewCreditSaleScreen> createState() =>
      _NewCreditSaleScreenState();
}

class _NewCreditSaleScreenState extends ConsumerState<NewCreditSaleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedCustomerId;
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

  Future<void> _onSave() async {
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

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(ledgerRepositoryProvider);
      await repo.addCredit(
        customerId: _selectedCustomerId!,
        amountSantim: santim,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.creditSaleSuccess),
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.newCreditSaleTitle),
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
                const SizedBox(height: 24),

                // Amount Field
                Text(
                  l10n.saleAmount,
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
                    color: AppColors.primary,
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
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  validator: (value) {
                    final santim = tryParseBirrToSantim(value);
                    if (santim == null || santim <= 0) {
                      return l10n.invalidAmount;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Quick Increment Chips (+500, +1,000, +2,000)
                AmountChipRow(
                  amounts: const [500, 1000, 2000],
                  onSelected: _addQuickAmount,
                ),
                const SizedBox(height: 24),

                // Note / Items
                Text(
                  l10n.itemsNote,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: l10n.itemsNoteHint,
                    prefixIcon: const Icon(Icons.shopping_bag_outlined),
                  ),
                ),
                const SizedBox(height: 36),

                // Save Button
                AstawashPrimaryButton(
                  label: l10n.saveCreditSale,
                  isLoading: _isSaving,
                  onPressed: _onSave,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
