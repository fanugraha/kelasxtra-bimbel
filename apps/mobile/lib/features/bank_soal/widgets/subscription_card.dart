import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../bank_soal_providers.dart';
import '../bank_soal_repository.dart';

/// Kartu langganan Bank Soal.
/// - Belum berlangganan: daftar manfaat + harga + tombol Langganan.
/// - Aktif/tenggang: satu baris status ringkas + tombol Perpanjang, supaya
///   tidak memakan tempat dari navigasi mapel.
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
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final plan = ref.watch(planProvider).asData?.value;
    final aktif = sub?.bisaLatihan ?? false;

    final button = FilledButton(
      onPressed: buying ? null : onBuy,
      style: aktif
          ? FilledButton.styleFrom(
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            )
          : FilledButton.styleFrom(minimumSize: const Size(0, 46)),
      child: buying
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(aktif ? 'Perpanjang' : 'Langganan sekarang'),
    );

    final Widget body;
    if (aktif) {
      final s = sub!;
      body = Row(
        children: [
          Icon(
            s.tenggang ? Icons.warning_amber_rounded : Icons.verified_rounded,
            color: s.tenggang ? palette.warning : palette.success,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.tenggang ? 'Masa tenggang' : 'Langganan aktif',
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  s.tenggang
                      ? 'Perpanjang sebelum ${AppFormat.dateShort(s.graceUntil!)}'
                      : 'Berlaku sampai ${AppFormat.dateShort(s.currentPeriodEnd!)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          button,
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.lock_open_rounded, color: palette.brand),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Buka semua soal',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (plan != null)
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: AppFormat.rupiah(plan.price),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(
                        text: '/${plan.periodDays} hari',
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final b in const [
            'Latihan semua mapel & topik',
            'Tryout dengan waktu & nilai otomatis',
            'Pembahasan tiap soal + grafik kekuatanmu',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 17,
                    color: palette.success,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(b, style: theme.textTheme.bodyMedium)),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          button,
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg + 2),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          body,
          if (error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              error!,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
