import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/person_photo.dart';
import '../../../core/widgets/screen_head.dart';
import '../jadwal_grouping.dart';

/// Kepala detail kelas: latar tonal melengkung di bawah, tombol kembali &
/// chat di atas, nama + mapel di kiri, foto besar di kanan.
class PersonHero extends StatelessWidget {
  const PersonHero({
    super.key,
    required this.person,
    required this.isSiswa,
    required this.onChat,
  });

  final JadwalPerson person;
  final bool isSiswa;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final next = person.next;
    final top = MediaQuery.paddingOf(context).top;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        top + AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl + 4,
      ),
      decoration: BoxDecoration(
        color: palette.brandSoft,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.xl + 8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconAction(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Kembali',
                onTap: () => context.pop(),
              ),
              const Spacer(),
              IconAction(
                icon: Icons.forum_outlined,
                tooltip: isSiswa ? 'Chat tutor' : 'Chat siswa',
                onTap: onChat,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSiswa ? 'Tutor' : 'Siswa',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      person.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _Line(
                      icon: Icons.menu_book_rounded,
                      text: person.subjects.join(', '),
                    ),
                    const SizedBox(height: 6),
                    _Line(
                      icon: next != null
                          ? Icons.schedule_rounded
                          : Icons.event_available_rounded,
                      text: next != null
                          ? 'Berikutnya ${AppFormat.dayLabel(next.scheduledAt)}, '
                                '${AppFormat.hm(next.scheduledAt)}'
                          : 'Belum ada jadwal baru',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surface, width: 4),
                ),
                child: PersonPhoto(
                  name: person.name,
                  photoUrl: person.photoUrl,
                  subjectLine: person.subjects.firstOrNull,
                  size: 104,
                  radius: 52,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurface),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
