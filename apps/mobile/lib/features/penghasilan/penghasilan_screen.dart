import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_view.dart';
import '../../widgets/empty_state.dart';
import 'penghasilan_providers.dart';
import 'penghasilan_repository.dart';

/// Slip penghasilan tutor. Hanya baca — transfer dilakukan admin via bank.
class PenghasilanScreen extends ConsumerWidget {
  const PenghasilanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payouts = ref.watch(myPayoutsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Penghasilan')),
      body: AsyncView<List<PayoutItem>>(
        value: payouts,
        errorTitle: 'Gagal memuat penghasilan',
        onRetry: () => ref.invalidate(myPayoutsProvider),
        builder: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Belum ada slip',
              message: 'Slip muncul setelah admin membuat rekap payroll.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myPayoutsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (c, i) => _PayoutCard(payout: list[i]),
            ),
          );
        },
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
    final color = switch (payout.status) {
      'paid' => Colors.green,
      'approved' => Colors.orange,
      _ => theme.colorScheme.onSurfaceVariant,
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${AppFormat.dateShort(payout.periodStart)} – '
                  '${AppFormat.dateShort(payout.periodEnd)}',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(payout.statusLabel,
                  style: theme.textTheme.labelMedium?.copyWith(color: color)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(AppFormat.rupiah(payout.amount), style: theme.textTheme.headlineSmall),
          if (payout.bankName != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(payout.bankName!, style: theme.textTheme.bodySmall),
          ],
          if (payout.transferRef != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Ref: ${payout.transferRef}', style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
