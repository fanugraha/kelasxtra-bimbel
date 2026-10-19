import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../bank_soal/bank_soal_repository.dart';
import '../../widgets/section_head.dart';
import '../mastery_data.dart';
import 'strength_chart.dart';

/// Beranda › Kekuatan & kelemahan (dari hasil latihan soal):
/// 1. Dua sorotan: MAPEL paling kuat & paling perlu latihan.
/// 2. Grafik batang per MAPEL (jumlahnya tetap sedikit & mudah dipahami),
///    tiap mapel menyebut topik terlemahnya.
/// 3. Rangkuman per TOPIK (yang bisa dilatih): topik kuat + 3 terlemah,
///    lalu tautan ke grafik semua topik.

/// Topik "perlu dilatih" yang ditampilkan di Beranda.
const _weakLimit = 3;

class StudentFocus extends StatelessWidget {
  const StudentFocus({super.key, required this.stats});

  final List<TopicStat> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sorted = [...stats]..sort((a, b) => b.accuracy.compareTo(a.accuracy));
    final subjects = subjectRows(stats);
    final strong = sorted.where((s) => s.accuracy >= masteryTarget).toList();
    final weak = sorted.reversed
        .where((s) => s.accuracy < masteryTarget)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHead(
          title: 'Kekuatan & kelemahan',
          actionLabel: 'Bank Soal',
          onAction: () => context.push('/bank-soal'),
        ),
        const SizedBox(height: AppSpacing.md),
        if (sorted.isEmpty)
          AppCard(
            onTap: () => context.push('/bank-soal'),
            child: Row(
              children: [
                Icon(
                  Icons.insights_rounded,
                  size: 28,
                  color: context.palette.challenge,
                ),
                const SizedBox(width: AppSpacing.md),
                const Expanded(
                  child: Text(
                    'Kerjakan beberapa latihan soal dulu, nanti grafik '
                    'kekuatan & kelemahanmu muncul di sini.',
                  ),
                ),
              ],
            ),
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: _Highlight(title: 'Paling kuat', row: subjects.first),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: _Highlight(
                  title: 'Paling perlu latihan',
                  row: subjects.last,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Nilai per mapel',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Dari ${sorted.fold<int>(0, (n, s) => n + s.attemptsCount)} '
                  'soal yang sudah kamu kerjakan',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                Divider(height: 1, color: scheme.outline),
                const SizedBox(height: AppSpacing.md),
                StrengthChart(rows: subjects, captionBelow: true),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SummaryCard(strong: strong, weak: weak, topicCount: sorted.length),
        ],
      ],
    );
  }
}

/// Kotak sorotan di atas grafik: satu topik + nilainya, besar & berwarna.
class _Highlight extends StatelessWidget {
  const _Highlight({required this.title, required this.row});

  final String title;
  final MasteryRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mastery = Mastery.of(row.accuracy);
    final color = mastery.color(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(mastery.icon, size: 16, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${row.accuracy.round()}%',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            row.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
          Text(
            mastery.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

/// Rangkuman teks di bawah grafik (juga jadi versi "tabel" grafik).
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.strong,
    required this.weak,
    required this.topicCount,
  });

  final List<TopicStat> strong;

  /// Urut dari yang paling lemah; Beranda hanya menampilkan [_weakLimit].
  final List<TopicStat> weak;
  final int topicCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final kuat = Mastery.kuat.color(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Rangkuman',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _GroupTitle(
            icon: Mastery.kuat.icon,
            color: kuat,
            text: 'Sudah kuat (${strong.length})',
          ),
          const SizedBox(height: AppSpacing.sm),
          if (strong.isEmpty)
            Text(
              'Belum ada topik di atas ${masteryTarget.round()}%. Semangat!',
              style: theme.textTheme.bodySmall,
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in strong)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: kuat.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${s.topicName} · ${s.accuracy.round()}%',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: AppSpacing.lg),
          Divider(height: 1, color: scheme.outline),
          const SizedBox(height: AppSpacing.lg),
          _GroupTitle(
            icon: Mastery.lemah.icon,
            color: Mastery.lemah.color(context),
            text: weak.length > _weakLimit
                ? 'Perlu dilatih · $_weakLimit terlemah'
                : 'Perlu dilatih (${weak.length})',
          ),
          const SizedBox(height: AppSpacing.xs),
          if (weak.isEmpty)
            Text(
              'Semua topik sudah di atas target. Mantap!',
              style: theme.textTheme.bodySmall,
            )
          else
            for (final s in weak.take(_weakLimit))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.topicName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            '${Mastery.of(s.accuracy).label} · '
                            '${s.accuracy.round()}% · '
                            '${(masteryTarget - s.accuracy).ceil()}% lagi '
                            'menuju target',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    OutlinedButton(
                      onPressed: () => context.push('/bank-soal'),
                      // Ajakan latihan bank soal = CHALLENGE.
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.challenge,
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        textStyle: theme.textTheme.labelMedium,
                      ),
                      child: const Text('Latihan'),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: AppSpacing.md),
          TextButton.icon(
            onPressed: () => context.push('/kekuatan-topik'),
            icon: const Icon(Icons.bar_chart_rounded, size: 18),
            label: Text('Lihat grafik semua topik ($topicCount)'),
          ),
        ],
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
