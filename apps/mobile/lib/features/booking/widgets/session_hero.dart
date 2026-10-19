import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/person_photo.dart';
import '../../../core/widgets/screen_head.dart';
import '../../../core/widgets/status_badge.dart';
import '../booking_repository.dart';

/// Kepala Detail sesi: latar tonal melengkung (senada detail kelas di
/// Jadwal), mapel besar, lawan belajar, lalu pil tanggal/jam/durasi/mode.
class SessionHero extends StatelessWidget {
  const SessionHero({
    super.key,
    required this.booking,
    required this.isTutor,
    required this.onChat,
  });

  final BookingDetail booking;
  final bool isTutor;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final b = booking;
    final person = isTutor ? b.studentName : b.tutorName;
    final online = b.mode == 'online';

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        MediaQuery.paddingOf(context).top + AppSpacing.md,
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
                tooltip: isTutor ? 'Chat siswa' : 'Chat tutor',
                onTap: onChat,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          BookingBadge(status: b.status),
          const SizedBox(height: AppSpacing.sm),
          Text(
            b.subjectName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              PersonPhoto(
                name: person,
                photoUrl: isTutor ? null : b.tutorPhotoUrl,
                subjectLine: b.subjectName,
                size: 32,
                radius: 16,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${isTutor ? 'Siswa' : 'Bersama'} $person · ${b.jenjang}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Pill(
                icon: Icons.calendar_today_rounded,
                text: AppFormat.dayLabel(b.scheduledAt),
              ),
              _Pill(
                icon: Icons.schedule_rounded,
                text:
                    '${AppFormat.timeRangeFrom(b.scheduledAt, b.durationMinutes)} WIB',
              ),
              _Pill(
                icon: online ? Icons.videocam_outlined : Icons.place_outlined,
                text: online ? 'Online' : 'Tatap muka',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.primary),
          const SizedBox(width: 5),
          Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
