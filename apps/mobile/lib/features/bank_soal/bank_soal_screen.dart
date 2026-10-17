import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_view.dart';
import '../booking/snap_screen.dart';
import 'bank_soal_providers.dart';
import 'bank_soal_repository.dart';

class BankSoalScreen extends ConsumerStatefulWidget {
  const BankSoalScreen({super.key});

  @override
  ConsumerState<BankSoalScreen> createState() => _BankSoalScreenState();
}

class _BankSoalScreenState extends ConsumerState<BankSoalScreen> {
  var _buying = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final sub = ref.watch(mySubscriptionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Bank Soal')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(mySubscriptionProvider);
          ref.invalidate(myStatsProvider);
          ref.invalidate(topicsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            AsyncView<SubscriptionInfo?>(
              value: sub,
              errorTitle: 'Gagal memuat langganan',
              onRetry: () => ref.invalidate(mySubscriptionProvider),
              builder: (s) => _SubCard(
                sub: s,
                buying: _buying,
                error: _error,
                onBuy: _buy,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Latihan per topik', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            const _Topics(),
            const SizedBox(height: AppSpacing.xl),
            Text('Fokus Perbaikimu', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Topik dengan akurasi terendah — mulai dari sini.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            const _Stats(),
          ],
        ),
      ),
    );
  }

  Future<void> _buy() async {
    setState(() {
      _buying = true;
      _error = null;
    });
    try {
      final res = await ref.read(bankSoalRepositoryProvider).createSubscriptionSnap();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SnapScreen(redirectUrl: res.redirectUrl)),
      );
      if (!mounted) return;
      ref.invalidate(mySubscriptionProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }
}

class _SubCard extends ConsumerWidget {
  const _SubCard({
    required this.sub,
    required this.buying,
    required this.onBuy,
    this.error,
  });

  final SubscriptionInfo? sub;
  final bool buying;
  final VoidCallback onBuy;
  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final plan = ref.watch(planProvider).asData?.value;
    final aktif = sub?.bisaLatihan ?? false;

    return AppCard(
      gradient: aktif ? AppColors.gradient : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            aktif ? 'Langganan ${sub!.label}' : 'Bank Soal',
            style: theme.textTheme.titleLarge
                ?.copyWith(color: aktif ? Colors.white : null),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (aktif)
            Text(
              sub!.tenggang
                  ? 'Masa tenggang sampai ${AppFormat.dateShort(sub!.graceUntil!)} — segera perpanjang.'
                  : 'Berlaku sampai ${AppFormat.dateShort(sub!.currentPeriodEnd!)}.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
            )
          else
            Text(
              'Latihan per topik, pembahasan, dan analisis nilai. '
              '${plan == null ? '' : '${AppFormat.rupiah(plan.price)}/bulan.'}',
              style: theme.textTheme.bodyMedium,
            ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            style: aktif
                ? FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size(0, 48),
                  )
                : null,
            onPressed: buying ? null : onBuy,
            icon: buying
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.card_membership_rounded),
            label: Text(
              aktif ? 'Perpanjang langganan' : 'Langganan sekarang',
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(error!,
                style: TextStyle(
                  color: aktif ? Colors.white : theme.colorScheme.error,
                  fontSize: 13,
                )),
          ],
        ],
      ),
    );
  }
}

class _Topics extends ConsumerWidget {
  const _Topics();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(topicsProvider);
    final sub = ref.watch(mySubscriptionProvider).asData?.value;
    final bisa = sub?.bisaLatihan ?? false;

    return AsyncView<List<Map<String, dynamic>>>(
      value: topics,
      errorTitle: 'Gagal memuat topik',
      onRetry: () => ref.invalidate(topicsProvider),
      builder: (list) => Column(
        children: [
          for (final t in list)
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              onTap: bisa
                  ? () => context.push(
                        '/latihan/${t['id']}',
                        extra: {
                          'name': t['name'],
                          'jenjang': t['jenjang'],
                        },
                      )
                  : null,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((t['name'] ?? '-') as String,
                            style: Theme.of(context).textTheme.titleSmall),
                        Text(
                          '${((t['subjects'] as Map?)?['name'] ?? '-')} · ${t['jenjang'] ?? '-'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    bisa ? Icons.play_circle_outline_rounded : Icons.lock_outline_rounded,
                    color: bisa ? AppColors.primary : Colors.grey,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Stats extends ConsumerWidget {
  const _Stats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(myStatsProvider);
    final theme = Theme.of(context);

    return AsyncView<List<TopicStat>>(
      value: stats,
      errorTitle: 'Gagal memuat analisis',
      onRetry: () => ref.invalidate(myStatsProvider),
      builder: (list) => list.isEmpty
          ? Text('Belum ada data. Kerjakan latihan pertamamu.',
              style: theme.textTheme.bodySmall)
          : Column(
              children: [
                for (final s in list.take(5))
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(s.topicName,
                                  style: theme.textTheme.titleSmall),
                            ),
                            _KategoriChip(kategori: s.kategori),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Text('Akurasi ${s.accuracy.toStringAsFixed(0)}%',
                                style: theme.textTheme.bodyMedium),
                            const SizedBox(width: AppSpacing.sm),
                            if (s.trend != null)
                              Text(
                                s.trend == 'naik'
                                    ? '↑ naik'
                                    : s.trend == 'turun'
                                        ? '↓ turun'
                                        : '→ stabil',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: s.trend == 'naik'
                                      ? AppColors.success
                                      : s.trend == 'turun'
                                          ? AppColors.danger
                                          : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            const Spacer(),
                            Text('20 terakhir ${s.last20Correct}/${s.last20Total}',
                                style: theme.textTheme.bodySmall),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: s.accuracy / 100,
                            minHeight: 8,
                            backgroundColor:
                                theme.colorScheme.primary.withValues(alpha: 0.12),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _KategoriChip extends StatelessWidget {
  const _KategoriChip({required this.kategori});
  final String kategori;

  @override
  Widget build(BuildContext context) {
    final color = switch (kategori) {
      'KUAT' => AppColors.success,
      'CUKUP' => AppColors.warning,
      _ => AppColors.danger,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(kategori,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
