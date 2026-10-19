import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/errors.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/screen_head.dart';
import '../auth/auth_providers.dart';
import '../booking/qris_screen.dart';
import 'bank_soal_providers.dart';
import 'bank_soal_repository.dart';
import 'widgets/stats_list.dart';
import 'widgets/subscription_card.dart';
import 'widgets/topics_list.dart';
import 'widgets/tryout_hero.dart';

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
    final profile = ref.watch(myProfileProvider);
    final bisa = sub.asData?.value?.bisaLatihan ?? false;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(mySubscriptionProvider);
          ref.invalidate(myStatsProvider);
          ref.invalidate(topicsProvider);
          ref.invalidate(myProfileProvider);
        },
        child: ListView(
          padding: screenPadding,
          children: [
            const ScreenHead(
              showBack: true,
              eyebrow: 'Latihan mandiri',
              title: 'Bank Soal',
              subtitle: 'Tryout dan latihan per topik, lengkap dengan pembahasan.',
            ),
            const SizedBox(height: 18),
            AsyncView<SubscriptionInfo?>(
              value: sub,
              errorTitle: 'Gagal memuat langganan',
              onRetry: () => ref.invalidate(mySubscriptionProvider),
              builder: (s) => SubscriptionCard(
                sub: s,
                buying: _buying,
                error: _error,
                onBuy: _buy,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TryoutHero(
              enabled: bisa,
              onTap: () => context.push(
                '/tryout',
                extra: {'jenjang': profile.asData?.value.jenjang},
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Latihan per topik', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            const TopicList(),
            const SizedBox(height: AppSpacing.xl),
            Text('Fokus Perbaikimu', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Topik dengan akurasi terendah — mulai dari sini.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            const StatsList(),
          ],
        ),
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
        MaterialPageRoute(builder: (_) => QrisScreen(result: res)),
      );
      if (!mounted) return;
      ref.invalidate(mySubscriptionProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = cleanError(e));
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }
}
