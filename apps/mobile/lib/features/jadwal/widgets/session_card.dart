import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/format.dart';
import '../../../core/meeting_link.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../booking/booking_repository.dart';

/// Kartu satu sesi di agenda Jadwal: jam, mata pelajaran, lawan bicara,
/// mode/durasi, lalu aksi utama (bayar, detail, ulasan) + chat.
class SessionCard extends StatelessWidget {
  const SessionCard({super.key, required this.booking, required this.isSiswa});

  final BookingItem booking;
  final bool isSiswa;

  bool get _pending => booking.status == 'pending_payment';

  bool get _canChat =>
      booking.status != 'pending_payment' && booking.status != 'expired';

  String get _primaryLabel => _canJoin
      ? 'Gabung Zoom'
      : switch (booking.status) {
          'pending_payment' => 'Bayar sekarang',
          'completed' => 'Beri ulasan',
          _ => 'Detail sesi',
        };

  /// Tombol utama berubah jadi "Gabung Zoom" hanya saat jendela waktunya buka.
  MeetingStatus get _meeting => meetingStatus(
    mode: booking.mode,
    status: booking.status,
    scheduledAt: booking.scheduledAt,
    durationMinutes: booking.durationMinutes,
    url: booking.meetingUrl,
  );

  bool get _canJoin => _meeting.canJoin;

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
    final initial = person.isEmpty ? '?' : person[0].toUpperCase();
    void openDetail() => context.push('/sesi/${booking.id}');
    void primary() {
      if (_pending) {
        context.push('/paket');
      } else if (_canJoin) {
        _openMeeting(context);
      } else {
        openDetail();
      }
    }

    return AppCard(
      onTap: openDetail,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TimeBlock(at: booking.scheduledAt),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            booking.subjectName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontSize: 14.5,
                              height: 1.25,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        BookingBadge(status: booking.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${booking.jenjang} · ${booking.durationMinutes} menit',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: scheme.primary.withValues(
                            alpha: 0.11,
                          ),
                          child: Text(
                            initial,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            '$personLabel $person',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          booking.mode == 'online'
                              ? Icons.videocam_outlined
                              : Icons.place_outlined,
                          size: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          booking.mode == 'online' ? 'Online' : 'Offline',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${AppFormat.timeRangeFrom(booking.scheduledAt, booking.durationMinutes)} WIB',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: primary,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    textStyle: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: Text(_primaryLabel),
                ),
              ),
              if (_canChat) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: openDetail,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 42),
                      textStyle: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: const Text('Chat'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Blok jam di kiri kartu: hari singkat + jam besar.
class _TimeBlock extends StatelessWidget {
  const _TimeBlock({required this.at});

  final DateTime at;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          Text(
            AppFormat.shortDayName(at.weekday % 7),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            AppFormat.dateNumber(at),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: scheme.primary.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            AppFormat.hm(at),
            style: TextStyle(
              fontSize: 16,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            'WIB',
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: scheme.primary.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}
