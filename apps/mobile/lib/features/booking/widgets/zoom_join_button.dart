import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/meeting_link.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';

/// Tombol "Gabung Zoom" yang sadar waktu: hanya aktif 15 menit sebelum
/// jadwal sampai 15 menit setelah sesi berakhir (lihat [meetingStatus]).
/// Dipakai di Detail sesi dan kartu agenda Jadwal.
class ZoomJoinButton extends StatelessWidget {
  const ZoomJoinButton({
    super.key,
    required this.status,
    required this.url,
    this.isTutor = false,
    this.onAddLink,
  });

  final MeetingStatus status;
  final String? url;

  /// Tentor bisa diminta menambahkan tautan saat belum ada.
  final bool isTutor;
  final VoidCallback? onAddLink;

  Future<void> _open(BuildContext context) async {
    final link = url;
    if (link == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await launchUrl(
        Uri.parse(link),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Tautan Zoom tidak bisa dibuka di perangkat ini.'),
          ),
        );
      }
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
    if (!status.isRelevant) return const SizedBox.shrink();

    if (status.phase == MeetingPhase.belumAdaLink) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.videocam_off_outlined,
                  size: 17,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Tautan Zoom belum ada',
                    style: theme.textTheme.titleSmall?.copyWith(fontSize: 13.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              isTutor
                  ? 'Tempel tautan Zoom sesi ini supaya siswa bisa bergabung.'
                  : 'Tentor belum menambahkan tautan. Kamu bisa mengingatkan lewat chat.',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
            ),
            if (isTutor && onAddLink != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Tambahkan tautan Zoom',
                icon: Icons.add_link_rounded,
                variant: AppButtonVariant.secondary,
                onPressed: onAddLink,
              ),
            ],
          ],
        ),
      );
    }

    if (status.phase == MeetingPhase.sudahLewat) {
      return AppCard(
        child: Row(
          children: [
            Icon(
              Icons.videocam_outlined,
              size: 17,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Sesi daring ini sudah berakhir.',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    final open = status.canJoin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppButton(
          label: 'Gabung Zoom',
          icon: Icons.videocam_rounded,
          onPressed: open ? () => _open(context) : null,
        ),
        if (!open && status.opensAt != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Aktif ${meetingCountdown(status.opensAt!)}. Tautan dibuka 15 menit sebelum sesi.',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
          ),
        ],
      ],
    );
  }
}

/// "dalam 3 jam 20 menit" / "sekarang" — dipakai sebagai keterangan tombol.
String meetingCountdown(DateTime opensAt, {DateTime? now}) {
  final diff = opensAt.difference(now ?? DateTime.now());
  if (diff.inMinutes <= 0) return 'sekarang';
  if (diff.inHours >= 1) {
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    return minutes == 0
        ? 'dalam $hours jam'
        : 'dalam $hours jam $minutes menit';
  }
  return 'dalam ${diff.inMinutes} menit';
}
