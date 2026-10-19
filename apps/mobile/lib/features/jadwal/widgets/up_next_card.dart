import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/format.dart';
import '../../../core/meeting_link.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/person_photo.dart';
import '../../booking/booking_repository.dart';

/// Kartu sesi terdekat di puncak Jadwal (gaya "Today's Class"): pil jam,
/// mapel besar, lawan belajar, lalu tombol Gabung Zoom yang menyala sendiri
/// saat kelas dibuka — siswa tidak perlu masuk ke tutor dulu untuk link.
class UpNextCard extends StatefulWidget {
  const UpNextCard({super.key, required this.booking, required this.isSiswa});

  final BookingItem booking;
  final bool isSiswa;

  @override
  State<UpNextCard> createState() => _UpNextCardState();
}

class _UpNextCardState extends State<UpNextCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Perbarui label waktu & tombol gabung tanpa perlu tarik ulang layar.
    _tick = Timer.periodic(
      const Duration(seconds: 30),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _join(String url) async {
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

  /// "Mulai dalam 25 menit" / "Sedang berlangsung" / "Besok, 16.00".
  String _when(BookingItem b) {
    final now = DateTime.now();
    final end = b.scheduledAt.add(Duration(minutes: b.durationMinutes));
    if (now.isAfter(b.scheduledAt) && now.isBefore(end)) {
      return 'Sedang berlangsung';
    }
    final diff = b.scheduledAt.difference(now);
    if (!diff.isNegative && diff.inMinutes < 60) {
      return 'Mulai dalam ${diff.inMinutes.clamp(1, 59)} menit';
    }
    if (!diff.isNegative && diff.inHours < 6) {
      return 'Mulai dalam ${diff.inHours} jam';
    }
    return '${AppFormat.dayLabel(b.scheduledAt)}, ${AppFormat.hm(b.scheduledAt)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final b = widget.booking;
    final person = widget.isSiswa ? b.tutorName : b.studentName;
    final online = b.mode == 'online';
    final meeting = meetingStatus(
      mode: b.mode,
      status: b.status,
      scheduledAt: b.scheduledAt,
      durationMinutes: b.durationMinutes,
      url: b.meetingUrl,
    );

    return Material(
      color: palette.brandSoft,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/sesi/${b.id}'),
        child: Stack(
          children: [
            // Ornamen lingkaran lembut di pojok (tanpa aset gambar).
            Positioned(
              right: -36,
              top: -36,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: palette.brand.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: 26,
              top: 58,
              child: Icon(
                subjectIconFor(b.subjectName),
                size: 64,
                color: palette.brand.withValues(alpha: 0.12),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: palette.brand,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.schedule_rounded,
                            size: 15,
                            color: palette.onBrand,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _when(b),
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    b.subjectName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      PersonPhoto(
                        name: person,
                        photoUrl: widget.isSiswa ? b.tutorPhotoUrl : null,
                        subjectLine: b.subjectName,
                        size: 26,
                        radius: 13,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.isSiswa ? 'Bersama $person' : 'Siswa $person',
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
                        text: AppFormat.timeRangeFrom(
                          b.scheduledAt,
                          b.durationMinutes,
                        ),
                      ),
                      _Pill(
                        icon: online
                            ? Icons.videocam_outlined
                            : Icons.place_outlined,
                        text: online ? 'Online' : 'Tatap muka',
                      ),
                      _Pill(
                        icon: Icons.timer_outlined,
                        text: '${b.durationMinutes} mnt',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: meeting.canJoin
                        ? FilledButton.icon(
                            onPressed: () => _join(b.meetingUrl!),
                            icon: const Icon(Icons.videocam_rounded, size: 19),
                            label: const Text('Gabung Zoom sekarang'),
                          )
                        : FilledButton.tonalIcon(
                            onPressed: () => context.push('/sesi/${b.id}'),
                            style: FilledButton.styleFrom(
                              backgroundColor: scheme.surface,
                              foregroundColor: palette.brand,
                            ),
                            icon: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 19,
                            ),
                            label: const Text('Lihat detail sesi'),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: context.palette.brand.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: scheme.onSurface),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
