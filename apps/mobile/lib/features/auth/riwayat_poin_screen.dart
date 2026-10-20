import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/screen_head.dart';
import '../booking/booking_providers.dart';
import 'auth_providers.dart';
import 'auth_repository.dart';

/// Poin saya: saldo besar + cara kerja poin + riwayat masuk/terpakai.
/// 1 poin = Rp1, dari kompensasi; dipakai memotong pembayaran.
class RiwayatPoinScreen extends ConsumerWidget {
  const RiwayatPoinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final saldo = ref.watch(myCreditProvider).value ?? 0;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myCreditProvider);
            ref.invalidate(creditHistoryProvider);
          },
          child: ListView(
            padding: screenPadding,
            children: [
              const ScreenHead(showBack: true, title: 'Poin saya'),
              const SizedBox(height: AppSpacing.xl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg + 2),
                decoration: BoxDecoration(
                  color: palette.rewardSoft,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: palette.reward,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        Icons.savings_rounded,
                        color: palette.onReward,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Saldo poin', style: theme.textTheme.labelLarge),
                          Text(
                            AppFormat.rupiah(saldo),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                            ),
                          ),
                          Text(
                            'Otomatis bisa dipakai saat bayar',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md + 2),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: scheme.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cara kerja poin',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (final t in const [
                      '1 poin = Rp1.',
                      'Poin didapat dari kompensasi, mis. tutor tidak hadir '
                          'atau paket dibatalkan.',
                      'Pakai poin dengan menyalakan "Pakai poin" saat membayar.',
                      'Poin tidak bisa dicairkan menjadi uang.',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 7),
                              child: Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: palette.reward,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(t, style: theme.textTheme.bodySmall),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Riwayat poin',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AsyncView<List<CreditEntry>>(
                value: ref.watch(creditHistoryProvider),
                errorTitle: 'Gagal memuat riwayat poin',
                onRetry: () => ref.invalidate(creditHistoryProvider),
                builder: (list) => list.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Text(
                          'Belum ada riwayat poin.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: scheme.outline),
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < list.length; i++) ...[
                              if (i > 0)
                                Divider(
                                  height: 1,
                                  indent: 60,
                                  color: scheme.outline,
                                ),
                              _EntryRow(entry: list[i]),
                            ],
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final CreditEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final masuk = entry.amount > 0;
    final color = masuk ? palette.success : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: masuk ? palette.successSoft : scheme.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(
              masuk ? Icons.south_west_rounded : Icons.north_east_rounded,
              size: 17,
              color: color,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.label, style: theme.textTheme.titleSmall),
                Text(
                  AppFormat.dateTimeShort(entry.createdAt),
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
          Text(
            '${masuk ? '+' : '−'}${AppFormat.rupiah(entry.amount.abs())}',
            style: theme.textTheme.titleSmall?.copyWith(
              color: masuk ? palette.success : scheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
