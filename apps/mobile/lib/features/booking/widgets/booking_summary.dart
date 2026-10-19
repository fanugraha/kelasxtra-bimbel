import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../booking_repository.dart';

/// Ringkasan sesi: identitas, jadwal, dan tempat — satu kartu.
/// Uang (harga sesi, refund) tidak ditampilkan di sini; rinciannya ada di
/// halaman Riwayat transaksi.
class BookingSummary extends StatelessWidget {
  const BookingSummary({super.key, required this.booking});

  final BookingDetail booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final online = booking.mode == 'online';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  booking.tutorName,
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 16.5),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              BookingBadge(status: booking.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${booking.subjectName} · ${booking.jenjang} · '
            '${booking.durationMinutes} menit',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.5),
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: scheme.outline),
          const SizedBox(height: AppSpacing.md),
          _MetaRow(
            icon: Icons.event_rounded,
            text: '${AppFormat.dateShort(booking.scheduledAt)} · '
                '${AppFormat.timeRangeFrom(booking.scheduledAt, booking.durationMinutes)} WIB',
          ),
          const SizedBox(height: AppSpacing.sm),
          _MetaRow(
            icon: online ? Icons.videocam_outlined : Icons.place_outlined,
            text: online ? 'Online (video call)' : 'Offline (tatap muka)',
          ),
          if (booking.address != null && booking.address!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _MetaRow(icon: Icons.home_outlined, text: booking.address!),
          ],
        ],
      ),
    );
  }
}

/// Satu baris keterangan dengan ikon kecil di kiri.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
          ),
        ),
      ],
    );
  }
}
