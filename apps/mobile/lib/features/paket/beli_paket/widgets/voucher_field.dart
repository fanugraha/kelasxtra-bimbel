import 'package:flutter/material.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/form_group.dart';
import '../beli_paket_controller.dart';

/// Kolom kode voucher + tombol Terapkan (pratinjau diskon dari server).
class VoucherField extends StatelessWidget {
  const VoucherField({
    super.key,
    required this.controller,
    required this.onApply,
    required this.onClear,
  });

  final BeliPaketController controller;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = controller;
    final applied = c.voucherCode != null;
    return FieldGroup(
      label: 'Kode voucher',
      hint: 'Opsional. Satu voucher per transaksi.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: c.voucher,
                  enabled: !applied && !c.checkingVoucher,
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => onApply(),
                  decoration: InputDecoration(
                    hintText: applied ? c.voucherCode : 'Contoh: HEMAT50',
                    prefixIcon: const Icon(
                      Icons.confirmation_number_outlined,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppButton(
                label: applied ? 'Hapus' : 'Terapkan',
                expand: false,
                variant: applied
                    ? AppButtonVariant.secondary
                    : AppButtonVariant.primary,
                loading: c.checkingVoucher,
                onPressed: applied ? onClear : onApply,
              ),
            ],
          ),
          if (c.voucherError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 15,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    c.voucherError!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ] else if (applied) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 15,
                  color: AppColors.success,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Diskon ${AppFormat.rupiah(c.voucherDiscount)} diterapkan.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.success,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
