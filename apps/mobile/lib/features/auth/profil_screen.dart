import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_flavor.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_view.dart';
import '../bank_soal/bank_soal_providers.dart';
import '../bank_soal/bank_soal_repository.dart';
import 'auth_providers.dart';
import 'auth_repository.dart';

class ProfilScreen extends ConsumerWidget {
  const ProfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);
    final isSiswa = ref.watch(appFlavorProvider) == AppFlavor.siswa;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myProfileProvider);
          ref.invalidate(mySubscriptionProvider);
        },
        child: AsyncView<MyProfile>(
          value: profile,
          errorTitle: 'Gagal memuat profil',
          onRetry: () => ref.invalidate(myProfileProvider),
          builder: (p) => ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              _Header(profile: p),
              if (p.jenjang != null) ...[
                const SizedBox(height: AppSpacing.xl),
                Text('Data siswa', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                _StudentCard(profile: p),
              ],
              if (isSiswa) ...[
                const SizedBox(height: AppSpacing.xl),
                Text('Langganan', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                const _SubscriptionCard(),
              ],
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: 'Keluar',
                icon: Icons.logout_rounded,
                variant: AppButtonVariant.secondary,
                onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final MyProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = profile.fullName ?? profile.email ?? 'Pengguna';
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: Text(
            initial,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: theme.textTheme.titleLarge),
              if (profile.email != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(profile.email!, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.profile});

  final MyProfile profile;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          _Row(label: 'Jenjang', value: profile.jenjang),
          if (profile.school != null) _Row(label: 'Sekolah', value: profile.school),
          if (profile.emergencyContactName != null)
            _Row(label: 'Kontak darurat', value: profile.emergencyContactName),
          if (profile.emergencyContactPhone != null)
            _Row(label: 'Telepon darurat', value: profile.emergencyContactPhone),
        ],
      ),
    );
  }
}

class _SubscriptionCard extends ConsumerWidget {
  const _SubscriptionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(mySubscriptionProvider);

    return AsyncView<SubscriptionInfo?>(
      value: sub,
      errorTitle: 'Gagal memuat langganan',
      onRetry: () => ref.invalidate(mySubscriptionProvider),
      builder: (s) {
        final aktif = s?.bisaLatihan ?? false;
        final detail = switch (s?.status) {
          'active' when s?.currentPeriodEnd != null =>
            'Berlaku sampai ${AppFormat.dateShort(s!.currentPeriodEnd!)}',
          'grace' when s?.graceUntil != null =>
            'Tenggang sampai ${AppFormat.dateShort(s!.graceUntil!)}',
          _ => 'Latihan bank soal belum aktif',
        };

        return AppCard(
          gradient: aktif ? AppColors.gradient : null,
          onTap: () => context.go('/bank-soal'),
          child: Row(
            children: [
              Icon(
                aktif ? Icons.verified_rounded : Icons.lock_outline_rounded,
                color: aktif ? Colors.white : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s?.label ?? 'Belum aktif',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: aktif ? Colors.white : null,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      detail,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: aktif ? Colors.white70 : null,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: aktif ? Colors.white70 : Theme.of(context).colorScheme.outline,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value ?? '—',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
