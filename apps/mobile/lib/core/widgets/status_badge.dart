import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

enum StatusTone { success, warning, info, neutral, danger }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
  });

  final String label;
  final StatusTone tone;

  /// Warna (isi, latar) per nada — dari palette agar benar di mode gelap.
  (Color, Color) _colors(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return switch (tone) {
      StatusTone.success => (p.success, p.successSoft),
      StatusTone.warning => (p.warning, p.warningSoft),
      StatusTone.info => (p.info, p.infoSoft),
      StatusTone.danger => (p.danger, p.dangerSoft),
      StatusTone.neutral => (
        scheme.onSurfaceVariant,
        scheme.surfaceContainerHighest,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (c, bg) = _colors(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: c,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

({String label, StatusTone tone}) bookingStatusMeta(String status) =>
    switch (status) {
      'confirmed' => (label: 'Terkonfirmasi', tone: StatusTone.success),
      'completed' => (label: 'Selesai', tone: StatusTone.neutral),
      'in_progress' => (label: 'Berlangsung', tone: StatusTone.warning),
      'pending_payment' => (label: 'Menunggu bayar', tone: StatusTone.warning),
      'rescheduled' => (label: 'Dijadwalkan ulang', tone: StatusTone.info),
      'no_show_tutor' => (label: 'Tutor tidak hadir', tone: StatusTone.danger),
      'no_show_student' => (
        label: 'Siswa tidak hadir',
        tone: StatusTone.danger,
      ),
      'cancelled' => (label: 'Dibatalkan', tone: StatusTone.danger),
      'expired' => (label: 'Kedaluwarsa', tone: StatusTone.neutral),
      'refunded' => (label: 'Dana kembali', tone: StatusTone.neutral),
      'disputed' => (label: 'Sengketa', tone: StatusTone.danger),
      _ => (label: status, tone: StatusTone.neutral),
    };

class BookingBadge extends StatelessWidget {
  const BookingBadge({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final meta = bookingStatusMeta(status);
    return StatusBadge(label: meta.label, tone: meta.tone);
  }
}
