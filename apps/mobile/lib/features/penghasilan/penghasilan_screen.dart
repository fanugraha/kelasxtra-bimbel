import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/screen_head.dart';
import '../../core/widgets/status_badge.dart';
import '../booking/booking_providers.dart';
import '../booking/booking_repository.dart';
import 'penghasilan_providers.dart';
import 'penghasilan_repository.dart';

/// Slip penghasilan tutor. Hanya baca — transfer dilakukan admin via bank.
class PenghasilanScreen extends ConsumerWidget {
  const PenghasilanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payouts = ref.watch(myPayoutsProvider);
    final bookings = ref.watch(jadwalProvider).value ?? const <BookingItem>[];
    final now = DateTime.now();
    final monthSessions = bookings
        .where((b) =>
            b.status == 'completed' &&
            b.scheduledAt.year == now.year &&
            b.scheduledAt.month == now.month)
        .toList();
    final estimate = monthSessions.fold<int>(
      0,
      (sum, b) => sum + (b.price * 75 ~/ 100),
    );

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myPayoutsProvider);
            ref.invalidate(jadwalProvider);
          },
          child: ListView(
            padding: screenPadding,
            children: [
              const ScreenHead(
                eyebrow: 'Penghasilan',
                title: 'Slip gaji',
                subtitle:
                    'Rekap dibuat admin setiap tanggal 25. Transfer dilakukan manual.',
              ),
              const SizedBox(height: 18),
              _MoneyCard(estimate: estimate, sessions: monthSessions.length),
              const SizedBox(height: 22),
              Text('Slip terbaru',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 17,
                        letterSpacing: -0.3,
                      )),
              const SizedBox(height: 9),
              AsyncView<List<PayoutItem>>(
                value: payouts,
                errorTitle: 'Gagal memuat penghasilan',
                onRetry: () => ref.invalidate(myPayoutsProvider),
                builder: (list) => list.isEmpty
                    ? const AppCard(
                        child: Text(
                            'Belum ada slip. Slip muncul setelah admin membuat rekap payroll.'),
                      )
                    : Column(
                        children: [
                          for (final p in list) ...[
                            _PayoutCard(payout: p),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoneyCard extends StatelessWidget {
  const _MoneyCard({required this.estimate, required this.sessions});
  final int estimate;
  final int sessions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ESTIMASI PERIODE BERJALAN',
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              )),
          const SizedBox(height: 6),
          Text(AppFormat.rupiah(estimate),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: 27,
                letterSpacing: -0.8,
              )),
          const SizedBox(height: 5),
          Text(
            '${AppFormat.dateLong(DateTime(DateTime.now().year, DateTime.now().month, 1))} – sekarang · $sessions sesi selesai',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _PayoutCard extends StatelessWidget {
  const _PayoutCard({required this.payout});

  final PayoutItem payout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = switch (payout.status) {
      'paid' => StatusTone.success,
      'approved' => StatusTone.warning,
      _ => StatusTone.neutral,
    };

    return AppCard(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppFormat.dateShort(payout.periodStart)} – '
                  '${AppFormat.dateShort(payout.periodEnd)}',
                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  payout.bankName == null
                      ? payout.statusLabel
                      : '${payout.statusLabel} · ${payout.bankName}',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                ),
                if (payout.transferRef != null) ...[
                  const SizedBox(height: 2),
                  Text('Ref: ${payout.transferRef}',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 9.5)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(AppFormat.rupiah(payout.amount),
                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 12)),
              const SizedBox(height: 3),
              StatusBadge(label: payout.statusLabel, tone: tone),
            ],
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded,
              size: 18, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
