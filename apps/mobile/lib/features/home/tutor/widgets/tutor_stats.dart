import 'package:flutter/material.dart';
import '../../../../core/dates.dart';

import '../../../../core/format.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../booking/booking_repository.dart';
import '../../../penghasilan/penghasilan_repository.dart';

/// Tiga kartu ringkasan untuk home tutor: sesi hari ini, check-in, penghasilan.
class TutorStats extends StatelessWidget {
  const TutorStats({super.key, required this.bookings, required this.payouts});

  final List<BookingItem> bookings;
  final List<PayoutItem> payouts;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = bookings.where((b) => isSameDay(b.scheduledAt, now)).toList();
    final needCheckIn = today.where((b) => b.status == 'confirmed').length;
    final payoutTotal = payouts
        .where(
          (p) => p.periodEnd.year == now.year && p.periodEnd.month == now.month,
        )
        .fold<int>(0, (sum, p) => sum + p.amount);
    final completedThisMonth = bookings.where(
      (b) =>
          b.status == 'completed' &&
          b.scheduledAt.year == now.year &&
          b.scheduledAt.month == now.month,
    );
    final estimate = completedThisMonth.fold<int>(
      0,
      (sum, b) => sum + (b.price * 75 ~/ 100),
    );
    final monthTotal = payoutTotal > 0 ? payoutTotal : estimate;

    return Row(
      children: [
        Expanded(
          child: _TutorStat(
            label: 'Sesi hari ini',
            value: '${today.length}',
            note: '${today.where((b) => b.mode == 'online').length} online',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TutorStat(
            label: 'Perlu check-in',
            value: '$needCheckIn',
            note: 'status terkonfirmasi',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TutorStat(
            label: 'Bulan ini',
            value: AppFormat.rupiah(monthTotal),
            note: 'estimasi',
          ),
        ),
      ],
    );
  }
}

class _TutorStat extends StatelessWidget {
  const _TutorStat({required this.label,
    required this.value,
    required this.note,
  });

  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 20,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 9.5),
          ),
        ],
      ),
    );
  }
}
