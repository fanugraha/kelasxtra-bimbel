import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/screen_head.dart';
import '../../bank_soal/bank_soal_providers.dart';
import '../../bank_soal/bank_soal_repository.dart';
import 'mastery_data.dart';
import 'widgets/strength_chart.dart';

/// Grafik lengkap per TOPIK (dibuka dari Beranda › "Lihat grafik semua
/// topik"). Beranda sengaja hanya menampilkan per mapel agar ringkas.
class TopicStrengthScreen extends ConsumerWidget {
  const TopicStrengthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = ref.watch(myStatsProvider);
    return Scaffold(
      body: SafeArea(
        child: AsyncView<List<TopicStat>>(
          value: stats,
          errorTitle: 'Gagal memuat nilai',
          onRetry: () => ref.invalidate(myStatsProvider),
          builder: (list) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(myStatsProvider),
            child: ListView(
              padding: screenPadding,
              children: [
                const ScreenHead(
                  showBack: true,
                  title: 'Semua topik',
                  subtitle:
                      'Nilai tiap topik dari latihan soalmu, '
                      'urut dari yang paling kuat.',
                ),
                const SizedBox(height: AppSpacing.xl),
                if (list.isEmpty)
                  const EmptyState(
                    icon: Icons.insights_rounded,
                    title: 'Belum ada nilai',
                    message: 'Kerjakan latihan soal dulu, ya.',
                  )
                else
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${list.length} topik',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        StrengthChart(rows: topicRows(list)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
