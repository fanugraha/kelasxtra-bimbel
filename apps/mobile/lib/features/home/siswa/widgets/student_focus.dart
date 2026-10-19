import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../bank_soal/bank_soal_repository.dart';
import '../../widgets/section_head.dart';

/// Kartu kekuatan & kelemahan berdasarkan akurasi topik.
class StudentFocus extends StatelessWidget {
  const StudentFocus({super.key, required this.stats});

  final List<TopicStat> stats;

  @override
  Widget build(BuildContext context) {
    final sorted = [...stats]..sort((a, b) => a.accuracy.compareTo(b.accuracy));
    final weak = sorted.isEmpty ? null : sorted.first;
    final strong = sorted.length < 2 ? null : sorted.last;

    return Column(
      children: [
        SectionHead(
          title: 'Kekuatan & kelemahan',
          actionLabel: 'Bank Soal',
          onAction: () => context.push('/bank-soal'),
        ),
        const SizedBox(height: AppSpacing.md),
        if (weak == null)
          AppCard(
            onTap: () => context.push('/bank-soal'),
            child: const Text(
              'Latihan beberapa soal untuk melihat kekuatan dan kelemahanmu.',
            ),
          )
        else ...[
          _TopicRow(stat: weak, strong: false),
          if (strong != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _TopicRow(stat: strong, strong: true),
          ],
        ],
      ],
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.stat, required this.strong});

  final TopicStat stat;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = strong ? AppColors.success : AppColors.warning;
    final pct = stat.accuracy.round();

    return AppCard(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              strong ? Icons.check_rounded : Icons.priority_high_rounded,
              size: 19,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.topicName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '${strong ? 'Kekuatan' : 'Kelemahan'} · akurasi $pct%',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: (stat.accuracy / 100).clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: theme.colorScheme.outline,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: () => context.push('/bank-soal'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: Text(strong ? 'Lihat' : 'Latihan'),
          ),
        ],
      ),
    );
  }
}
