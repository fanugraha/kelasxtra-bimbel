import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/format.dart';
import '../../../core/meeting_link.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/person_photo.dart';
import '../../../core/widgets/status_badge.dart';
import '../../booking/booking_repository.dart';

/// Kartu sesi terdekat bergaya janji temu Halodoc: foto tentor besar,
/// nama + mapel, satu baris jadwal, status, lalu satu tombol aksi.
class NextSessionCard extends StatelessWidget {
  const NextSessionCard({
    super.key,
    required this.booking,
    required this.isSiswa,
  });

  final BookingItem booking;
  final bool isSiswa;

  MeetingStatus get _meeting => meetingStatus(
    mode: booking.mode,
    status: booking.status,
    scheduledAt: booking.scheduledAt,
    durationMinutes: booking.durationMinutes,
    url: booking.meetingUrl,
  );

  Future<void> _openMeeting(BuildContext context) async {
    final url = booking.meetingUrl;
    if (url == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) throw Exception('gagal');
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Tautan Zoom tidak bisa dibuka di perangkat ini.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final person = isSiswa ? booking.tutorName : booking.studentName;
    final personLabel = isSiswa ? 'Tutor' : 'Siswa';
    final at = booking.scheduledAt;
    final online = booking.mode == 'online';
    final canJoin = _meeting.canJoin;

    void primary() {
      if (canJoin) {
        _openMeeting(context);
      } else {
        context.push('/sesi/${booking.id}');
      }
    }

    return AppCard(
      onTap: () => context.push('/sesi/${booking.id}'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PersonPhoto(
                name: person,
                photoUrl: isSiswa ? booking.tutorPhotoUrl : null,
                subjectLine: booking.subjectName,
                size: 68,
                radius: 20,
                showVerified: isSiswa,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.subjectName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$personLabel $person',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${booking.jenjang} · ${booking.durationMinutes} menit',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: scheme.outline),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: scheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '${AppFormat.dayLabel(at)} · '
                    '${AppFormat.timeRangeFrom(at, booking.durationMinutes)} WIB',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              BookingBadge(status: booking.status),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    online ? Icons.videocam_outlined : Icons.place_outlined,
                    size: 15,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    online ? 'Online' : 'Offline',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: primary,
              icon: Icon(
                canJoin ? Icons.videocam_rounded : Icons.arrow_forward_rounded,
                size: 19,
              ),
              label: Text(canJoin ? 'Gabung Zoom' : 'Lihat detail sesi'),
            ),
          ),
        ],
      ),
    );
  }
}
