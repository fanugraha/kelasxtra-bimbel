import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_view.dart';
import '../bank_soal_providers.dart';
import '../bank_soal_repository.dart';

/// Daftar analisis fokus perbaikan (akurasi terendah).
class StatsList extends ConsumerWidget {
  const StatsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(myStatsProvider);
    final theme = Theme.of(context);

    return AsyncView<List<TopicStat>>(
      value: stats,
      errorTitle: 'Gagal memuat analisis',
      onRetry: () => ref.invalidate(myStatsProvider),
      builder: (list) => list.isEmpty
          ? Text(
              'Belum ada data. Kerjakan latihan pertamamu.',
              style: theme.textTheme.bodySmall,
            )
          : Column(
              children: [
                for (final s in list.take(5))
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.topicName,
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                            _KategoriChip(kategori: s.kategori),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Text(
                              'Akurasi ${s.accuracy.toStringAsFixed(0)}%',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            if (s.trend != null)
                              Text(
                                s.trend == 'naik'
                                    ? '↑ naik'
                                    : s.trend == 'turun'
                                        ? '↓ turun'
                                        : '→ stabil',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: s.trend == 'naik'
                                      ? AppColors.success
                                      : s.trend == 'turun'
                                          ? AppColors.danger
                                          : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            const Spacer(),
                            Text(
                              '20 terakhir ${s.last20Correct}/${s.last20Total}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: s.accuracy / 100,
                            minHeight: 8,
                            backgroundColor: theme.colorScheme.primary
                                .withValues(alpha: 0.12),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _KategoriChip extends StatelessWidget {
  const _KategoriChip({required this.kategori});

  final String kategori;

  @override
  Widget build(BuildContext context) {
    final color = switch (kategori) {
      'KUAT' => AppColors.success,
      'CUKUP' => AppColors.warning,
      _ => AppColors.danger,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        kategori,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
