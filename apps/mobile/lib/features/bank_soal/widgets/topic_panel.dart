import 'package:flutter/material.dart';

import '../../../core/mastery.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/person_photo.dart';
import '../bank_soal_repository.dart';

/// Isi satu mapel: kepala (nama, jumlah topik & soal), lalu baris per topik
/// dengan jumlah soal, nilai siswa (tingkat penguasaan), dan ikon mulai/kunci.
/// Topik terkunci tetap bisa diketuk → [onLocked] menjelaskan cara membukanya.
class TopicPanel extends StatelessWidget {
  const TopicPanel({
    super.key,
    required this.subject,
    required this.topics,
    required this.stats,
    required this.unlocked,
    required this.onOpen,
    required this.onLocked,
    this.freeTopicId,
  });

  final String subject;
  final List<CatalogTopic> topics;

  /// Statistik siswa per `topicId`.
  final Map<String, TopicStat> stats;
  final bool unlocked;
  final ValueChanged<CatalogTopic> onOpen;
  final ValueChanged<CatalogTopic> onLocked;

  /// Topik yang punya paket coba gratis (diberi label).
  final String? freeTopicId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final totalSoal = topics.fold<int>(0, (n, t) => n + t.questionCount);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg + 2),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: palette.brandSoft,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    subjectIconFor(subject),
                    size: 21,
                    color: palette.brand,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${topics.length} topik · $totalSoal soal',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (!unlocked)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 15,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 3),
                      Text('Terkunci', style: theme.textTheme.labelSmall),
                    ],
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outline),
          for (var i = 0; i < topics.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 16, color: scheme.outline),
            _TopicRow(
              topic: topics[i],
              stat: stats[topics[i].topicId],
              unlocked: unlocked,
              free: !unlocked && topics[i].topicId == freeTopicId,
              onTap: () => unlocked || topics[i].questionCount == 0
                  ? onOpen(topics[i])
                  : onLocked(topics[i]),
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({
    required this.topic,
    required this.stat,
    required this.unlocked,
    required this.free,
    required this.onTap,
  });

  final CatalogTopic topic;
  final TopicStat? stat;
  final bool unlocked;
  final bool free;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final empty = topic.questionCount == 0;
    final m = stat == null ? null : Mastery.of(stat!.accuracy);

    return InkWell(
      onTap: empty ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          topic.topicName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      if (free) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: palette.promoSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Ada paket gratis',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: palette.promo,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        empty
                            ? 'Soal segera hadir'
                            : '${topic.questionCount} soal',
                        style: theme.textTheme.labelSmall,
                      ),
                      if (m != null) ...[
                        Text(' · ', style: theme.textTheme.labelSmall),
                        Icon(m.icon, size: 13, color: m.color(context)),
                        const SizedBox(width: 3),
                        Text(
                          '${stat!.accuracy.round()}% ${m.label}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ] else if (!empty) ...[
                        Text(' · ', style: theme.textTheme.labelSmall),
                        Text('Belum dicoba', style: theme.textTheme.labelSmall),
                      ],
                    ],
                  ),
                  if (m != null) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (stat!.accuracy / 100).clamp(0.0, 1.0),
                        minHeight: 5,
                        color: m.color(context),
                        backgroundColor: scheme.surfaceContainerHigh,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: empty
                    ? scheme.surfaceContainerHigh
                    : unlocked
                    ? palette.challenge
                    : scheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(
                empty
                    ? Icons.hourglass_empty_rounded
                    : unlocked
                    ? Icons.play_arrow_rounded
                    : Icons.lock_outline_rounded,
                size: 20,
                color: unlocked && !empty
                    ? palette.onChallenge
                    : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
