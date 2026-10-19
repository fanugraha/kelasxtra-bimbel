import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_error_text.dart';
import '../../../../core/widgets/credit_toggle.dart';
import '../../../../core/widgets/form_group.dart';
import '../../paket_providers.dart';
import '../beli_paket_controller.dart';
import '../widgets/price_card.dart';
import '../widgets/voucher_field.dart';

/// Bagian bayar: alamat (offline) + voucher + poin + rincian harga.
class StepRingkasan extends ConsumerWidget {
  const StepRingkasan({
    super.key,
    required this.controller,
    required this.onApplyVoucher,
    required this.onClearVoucher,
  });

  final BeliPaketController controller;
  final VoidCallback onApplyVoucher;
  final VoidCallback onClearVoucher;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = controller;
    final addressRequired = c.mode == 'offline';
    int? total;
    if (c.subject != null && c.mode != null) {
      total = ref
          .watch(
            packagePriceProvider((
              jenjang: c.subject!.jenjang,
              duration: c.duration,
              mode: c.mode!,
              totalSesi: c.size,
            )),
          )
          .value;
    }
    final afterVoucher = total == null
        ? null
        : (total - c.voucherDiscount).clamp(0, total);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (addressRequired) ...[
          FieldGroup(
            label: 'Alamat belajar',
            hint: 'Alamat lengkap supaya tutor tidak tersesat.',
            child: TextField(
              controller: c.address,
              minLines: 2,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              onChanged: (_) => c.refresh(),
              decoration: const InputDecoration(
                hintText: 'Contoh: Jl. Melati 12, RT 03/RW 05, Depok',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        VoucherField(
          controller: c,
          onApply: onApplyVoucher,
          onClear: onClearVoucher,
        ),
        CreditToggle(
          value: c.useCredits,
          onChanged: c.setUseCredits,
          total: afterVoucher,
        ),
        const SizedBox(height: AppSpacing.xl),
        PriceCard(
          subject: c.subject,
          mode: c.mode,
          duration: c.duration,
          size: c.size,
          discount: c.voucherDiscount,
          voucherCode: c.voucherCode,
        ),
        AppErrorText(c.error),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Slot semua pertemuan ditahan 30 menit saat kamu lanjut ke pembayaran.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
