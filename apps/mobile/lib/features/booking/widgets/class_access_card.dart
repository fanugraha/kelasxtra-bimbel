import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/meeting_link.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../booking_repository.dart';

/// Kartu utama Detail sesi: cara MASUK kelas.
///
/// - Online: tombol "Gabung Zoom" yang sadar waktu (aktif 15 menit sebelum
///   jadwal, lihat [meetingStatus]) + hitung mundur + salin tautan. Kartu
///   memperbarui dirinya tiap 30 detik, jadi tombol menyala sendiri tanpa
///   pengguna perlu menarik ulang layar.
/// - Offline: alamat belajar + buka di Maps.
class ClassAccessCard extends StatefulWidget {
  const ClassAccessCard({
    super.key,
    required this.booking,
    required this.isTutor,
    required this.onChat,
    this.onEditLink,
  });

  final BookingDetail booking;
  final bool isTutor;
  final VoidCallback onChat;

  /// Tentor: isi/ubah tautan Zoom.
  final VoidCallback? onEditLink;

  @override
  State<ClassAccessCard> createState() => _ClassAccessCardState();
}

class _ClassAccessCardState extends State<ClassAccessCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
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

  Future<void> _launch(Uri uri, String failText) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw Exception('gagal');
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failText)));
    }
  }

  Future<void> _copy(String link) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: link));
    messenger.showSnackBar(
      const SnackBar(content: Text('Tautan Zoom disalin.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    if (b.mode != 'online') return _offline(context);

    final status = meetingStatus(
      mode: b.mode,
      status: b.status,
      scheduledAt: b.scheduledAt,
      durationMinutes: b.durationMinutes,
      url: b.meetingUrl,
    );
    return switch (status.phase) {
      MeetingPhase.tidakBerlaku => const SizedBox.shrink(),
      MeetingPhase.belumAdaLink => _noLink(context),
      MeetingPhase.sudahLewat => _ended(context),
      MeetingPhase.belumWaktunya ||
      MeetingPhase.bisaGabung => _zoom(context, status),
    };
  }

  Widget _zoom(BuildContext context, MeetingStatus status) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final link = widget.booking.meetingUrl!;
    final open = status.canJoin;
    // Siswa baru bisa melihat/menyalin tautan saat jendela dibuka, supaya
    // tautan tidak tersebar jauh sebelum waktunya. Tentor pemilik tautan.
    final canCopy = open || widget.isTutor;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: open ? palette.successSoft : scheme.surfaceContainerLow,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
            ),
            child: Row(
              children: [
                _IconBubble(
                  icon: Icons.videocam_rounded,
                  bg: open ? palette.success : palette.brandSoft,
                  fg: open ? scheme.surface : palette.brand,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (open) ...[
                            _LiveDot(color: palette.success),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            open ? 'Kelas sudah dibuka' : 'Kelas dibuka',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: open
                                  ? palette.success
                                  : scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        open
                            ? 'Masuk sekarang lewat Zoom'
                            : _countdown(status.opensAt!),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppButton(
                  label: open ? 'Gabung Zoom' : 'Belum bisa bergabung',
                  icon: open ? Icons.videocam_rounded : Icons.lock_clock,
                  onPressed: open
                      ? () => _launch(
                          Uri.parse(link),
                          'Tautan Zoom tidak bisa dibuka di perangkat ini.',
                        )
                      : null,
                ),
                if (!open) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Tombol aktif otomatis 15 menit sebelum kelas dimulai.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                if (canCopy || widget.onEditLink != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _LinkRow(
                    link: link,
                    onCopy: canCopy ? () => _copy(link) : null,
                    onEdit: widget.onEditLink,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _noLink(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _IconBubble(
                icon: Icons.videocam_off_rounded,
                bg: palette.warningSoft,
                fg: palette.warning,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Link kelas belum tersedia',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.isTutor
                          ? 'Tempel tautan Zoom supaya siswa bisa bergabung.'
                          : 'Tutor belum menambahkan tautan Zoom.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (widget.isTutor && widget.onEditLink != null)
            AppButton(
              label: 'Tambahkan link Zoom',
              icon: Icons.add_link_rounded,
              onPressed: widget.onEditLink,
            )
          else
            AppButton(
              label: 'Ingatkan tutor lewat chat',
              icon: Icons.forum_outlined,
              variant: AppButtonVariant.secondary,
              onPressed: widget.onChat,
            ),
        ],
      ),
    );
  }

  Widget _ended(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      child: Row(
        children: [
          _IconBubble(
            icon: Icons.videocam_outlined,
            bg: scheme.surfaceContainerLow,
            fg: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Kelas online ini sudah berakhir.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _offline(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final address = widget.booking.address?.trim();
    final hasAddress = address != null && address.isNotEmpty;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBubble(
                icon: Icons.place_rounded,
                bg: palette.brandSoft,
                fg: palette.brand,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kelas tatap muka',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasAddress ? address : 'Alamat belum diisi.',
                      style: theme.textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasAddress) ...[
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Buka di Maps',
              icon: Icons.map_outlined,
              variant: AppButtonVariant.secondary,
              onPressed: () => _launch(
                Uri.https('www.google.com', '/maps/search/', {
                  'api': '1',
                  'query': address,
                }),
                'Maps tidak bisa dibuka di perangkat ini.',
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _countdown(DateTime opensAt) {
    final text = meetingCountdown(opensAt);
    return text == 'sekarang'
        ? 'Sebentar lagi'
        : text[0].toUpperCase() + text.substring(1);
  }
}

/// Tautan ringkas + Salin / Ubah.
class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.link, this.onCopy, this.onEdit});

  final String link;
  final VoidCallback? onCopy;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shown = link.replaceFirst(RegExp(r'^https?://'), '');
    return Container(
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.link_rounded, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              onCopy == null ? 'Tautan tampil saat kelas dibuka' : shown,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          if (onCopy != null)
            TextButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Salin'),
            ),
          if (onEdit != null)
            TextButton(onPressed: onEdit, child: const Text('Ubah')),
        ],
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.icon, required this.bg, required this.fg});

  final IconData icon;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(icon, size: 22, color: fg),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// "dalam 3 jam 20 menit" / "sekarang" — keterangan hitung mundur.
String meetingCountdown(DateTime opensAt, {DateTime? now}) {
  final diff = opensAt.difference(now ?? DateTime.now());
  if (diff.inMinutes <= 0) return 'sekarang';
  if (diff.inDays >= 2) return 'dalam ${diff.inDays} hari';
  if (diff.inHours >= 1) {
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    return minutes == 0
        ? 'dalam $hours jam'
        : 'dalam $hours jam $minutes menit';
  }
  return 'dalam ${diff.inMinutes} menit';
}
