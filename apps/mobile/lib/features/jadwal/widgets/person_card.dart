import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/person_photo.dart';
import '../jadwal_grouping.dart';

/// Satu tutor/siswa di langkah pertama Jadwal: foto, nama, mapel, lalu
/// pil sesi terdekat. Kartu teratas ([highlight]) diberi latar tonal brand.
class PersonCard extends StatelessWidget {
  const PersonCard({
    super.key,
    required this.person,
    required this.isSiswa,
    required this.onTap,
    this.highlight = false,
  });

  final JadwalPerson person;
  final bool isSiswa;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final next = person.next;
    final last = person.last;

    final String when;
    if (next != null) {
      when =
          '${AppFormat.dayLabel(next.scheduledAt)} · '
          '${AppFormat.hm(next.scheduledAt)}';
    } else if (last != null) {
      when = 'Terakhir ${AppFormat.dateNumber(last.scheduledAt)}';
    } else {
      when = '-';
    }

    final count = person.upcoming.length;
    final countLabel = count > 0
        ? '$count sesi lagi'
        : '${person.completedCount} selesai';

    final done = person.completedCount;
    final total = done + person.upcoming.length;

    return Material(
      color: highlight ? palette.brandSoft : scheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md + 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: highlight ? Colors.transparent : scheme.outline,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  PersonPhoto(
                    name: person.name,
                    photoUrl: person.photoUrl,
                    subjectLine: person.subjects.firstOrNull,
                    size: 60,
                    radius: 18,
                    showVerified: isSiswa,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          person.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          person.subjects.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _Pill(
                              icon: next != null
                                  ? Icons.calendar_today_rounded
                                  : Icons.history_rounded,
                              text: when,
                              strong: next != null,
                            ),
                            _Pill(
                              icon: Icons.event_note_rounded,
                              text: countLabel,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
              if (total > 0) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Text('Progres kelas', style: theme.textTheme.labelSmall),
                    const Spacer(),
                    Text(
                      '$done dari $total pertemuan',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: done / total,
                    minHeight: 6,
                    color: done == total ? palette.success : palette.brand,
                    backgroundColor: highlight
                        ? scheme.surface
                        : scheme.surfaceContainerHigh,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Pil kecil berikon seperti "16 Aug" / "Intensive" di referensi.
class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, this.strong = false});

  final IconData icon;
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = strong ? scheme.primary : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: strong ? scheme.onSurface : null,
              fontWeight: strong ? FontWeight.w700 : null,
            ),
          ),
        ],
      ),
    );
  }
}
