import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../booking/booking_providers.dart';
import '../booking/booking_repository.dart';

class JadwalScreen extends ConsumerWidget {
  const JadwalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(myBookingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Jadwal')),
      body: bookings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Gagal memuat jadwal',
          message: '$e',
          action: FilledButton.icon(
            onPressed: () => ref.invalidate(myBookingsProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba lagi'),
          ),
        ),
        data: (list) => list.isEmpty
            ? EmptyState(
                icon: Icons.event_busy_rounded,
                title: 'Belum ada sesi',
                message: 'Yuk cari tutor dan pesan sesi pertamamu.',
                action: FilledButton.icon(
                  onPressed: () => context.go('/katalog'),
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Cari Tutor'),
                ),
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(myBookingsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                  ),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (c, i) => _BookingCard(booking: list[i]),
                ),
              ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});

  final BookingItem booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(booking.tutorName, style: theme.textTheme.titleMedium),
              ),
              _StatusChip(status: booking.status, label: booking.statusLabel),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${booking.subjectName} · ${booking.jenjang} · ${booking.durationMinutes} menit',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(
                booking.mode == 'online' ? Icons.videocam_rounded : Icons.place_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(_formatDateTime(booking.scheduledAt), style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  static const _dayShort = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
  static const _monthShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  static String _formatDateTime(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${_dayShort[d.weekday % 7]}, ${d.day} ${_monthShort[d.month - 1]} · $hh:$mm';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.label});

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'confirmed' || 'completed' => AppColors.success,
      'pending_payment' || 'in_progress' || 'rescheduled' => AppColors.warning,
      'cancelled' || 'expired' || 'no_show_tutor' || 'no_show_student' => AppColors.danger,
      'refunded' || 'disputed' => AppColors.info,
      _ => AppColors.info,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
