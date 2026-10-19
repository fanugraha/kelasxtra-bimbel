import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../bank_soal_providers.dart';
import '../bank_soal_repository.dart';

/// Kartu status langganan Bank Soal beserta tombol beli/perpanjang.
class SubscriptionCard extends ConsumerWidget {
  const SubscriptionCard({
    super.key,
    required this.sub,
    required this.buying,
    required this.onBuy,
    this.error,
  });

  final SubscriptionInfo? sub;
  final bool buying;
  final VoidCallback onBuy;
  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final plan = ref.watch(planProvider).asData?.value;
    final aktif = sub?.bisaLatihan ?? false;

    return AppCard(
      gradient: aktif ? AppColors.gradient : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            aktif ? 'Langganan ${sub!.label}' : 'Bank Soal',
            style: theme.textTheme.titleLarge
                ?.copyWith(color: aktif ? Colors.white : null),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (aktif)
            Text(
              sub!.tenggang
                  ? 'Masa tenggang sampai ${AppFormat.dateShort(sub!.graceUntil!)} — segera perpanjang.'
                  : 'Berlaku sampai ${AppFormat.dateShort(sub!.currentPeriodEnd!)}.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
            )
          else
            Text(
              'Latihan per topik, pembahasan, dan analisis nilai. '
              '${plan == null ? '' : '${AppFormat.rupiah(plan.price)}/bulan.'}',
              style: theme.textTheme.bodyMedium,
            ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            style: aktif
                ? FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size(0, 48),
                  )
                : null,
            onPressed: buying ? null : onBuy,
            icon: buying
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.card_membership_rounded),
            label: Text(
              aktif ? 'Perpanjang langganan' : 'Langganan sekarang',
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              error!,
              style: TextStyle(
                color: aktif ? Colors.white : theme.colorScheme.error,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
