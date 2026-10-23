import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class AmountChip extends StatelessWidget {
  const AmountChip({
    super.key,
    required this.label,
    required this.onTap,
    this.isSelected = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.chipBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: isSelected ? AppColors.textOnPrimary : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class AmountChipRow extends StatelessWidget {
  const AmountChipRow({
    super.key,
    required this.amounts,
    required this.onSelected,
    this.customTrailingChip,
  });

  final List<int> amounts;
  final ValueChanged<int> onSelected;
  final Widget? customTrailingChip;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final amount in amounts)
          AmountChip(
            label: '+ ${amount >= 1000 ? "${amount ~/ 1000},000" : amount}',
            onTap: () => onSelected(amount),
          ),
        ?customTrailingChip,
      ],
    );
  }
}
