import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

enum StatusTone { success, warning, info, neutral, danger }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
  });

  final String label;
  final StatusTone tone;

  Color get color => switch (tone) {
        StatusTone.success => AppColors.success,
        StatusTone.warning => AppColors.warning,
        StatusTone.info => AppColors.info,
        StatusTone.danger => AppColors.danger,
        StatusTone.neutral => const Color(0xFF6B7280),
      };

  @override
  Widget build(BuildContext context) {
    final c = color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.13),
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
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: c,
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
      'no_show_student' => (label: 'Siswa tidak hadir', tone: StatusTone.danger),
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
