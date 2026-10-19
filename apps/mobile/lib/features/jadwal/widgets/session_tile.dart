import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/person_photo.dart';
import '../../../core/widgets/status_badge.dart';
import '../../booking/booking_repository.dart';

/// Satu titik pada timeline jadwal: jam di kiri, garis + titik di tengah,
/// lalu foto tentor dan ringkasan sesi di kanan.
class SessionTile extends StatelessWidget {
  const SessionTile({
    super.key,
    required this.booking,
    required this.isSiswa,
    required this.isFirst,
    required this.isLast,
    this.muted = false,
  });

  final BookingItem booking;
  final bool isSiswa;
  final bool isFirst;
  final bool isLast;

  /// Tab "Selesai": titik dan garis dibuat netral, bukan warna brand.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final person = isSiswa ? booking.tutorName : booking.studentName;
    final online = booking.mode == 'online';
    final showStatus = booking.status != 'completed';

    return InkWell(
      onTap: () => context.push('/sesi/${booking.id}'),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 46,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppFormat.hm(booking.scheduledAt),
                      maxLines: 1,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${booking.durationMinutes} mnt',
                      maxLines: 1,
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
            _TimelineRail(isFirst: isFirst, isLast: isLast, muted: muted),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PersonPhoto(
                      name: person,
                      photoUrl: isSiswa ? booking.tutorPhotoUrl : null,
                      subjectLine: booking.subjectName,
                      size: 42,
                      radius: 13,
                      showVerified: isSiswa,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.subjectName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            person,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (showStatus)
                                BookingBadge(status: booking.status),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    online
                                        ? Icons.videocam_outlined
                                        : Icons.place_outlined,
                                    size: 13,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    online ? 'Online' : 'Offline',
                                    style: theme.textTheme.labelSmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(top: 9),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Garis vertikal + titik. Garis berhenti di titik pertama dan terakhir
/// supaya tidak menggantung di ujung kelompok tanggal.
class _TimelineRail extends StatelessWidget {
  const _TimelineRail({
    required this.isFirst,
    required this.isLast,
    required this.muted,
  });

  final bool isFirst;
  final bool isLast;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dot = muted ? scheme.onSurfaceVariant : scheme.primary;
    final line = scheme.outline;
    const dotSize = 11.0;
    const centerY = 20.0;

    return SizedBox(
      width: 22,
      child: Stack(
        children: [
          if (!isFirst)
            Positioned(
              left: 10,
              top: 0,
              height: centerY,
              child: Container(width: 2, color: line),
            ),
          if (!isLast)
            Positioned(
              left: 10,
              top: centerY,
              bottom: 0,
              child: Container(width: 2, color: line),
            ),
          Positioned(
            left: 10 - dotSize / 2,
            top: centerY - dotSize / 2,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: scheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: dot, width: 2.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
