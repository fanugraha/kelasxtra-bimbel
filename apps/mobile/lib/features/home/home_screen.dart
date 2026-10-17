import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_flavor.dart';
import '../../core/providers.dart';
import '../../core/supabase_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../auth/auth_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flavor = ref.watch(appFlavorProvider);
    final isSiswa = flavor == AppFlavor.siswa;
    final user = supabase.auth.currentUser;
    final name = (user?.userMetadata?['full_name'] as String?)?.split(' ').first ??
        user?.email?.split('@').first ??
        'Kamu';

    return Scaffold(
      appBar: AppBar(
        title: Text('Hai, $name 👋'),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          _Hero(isSiswa: isSiswa),
          const SizedBox(height: AppSpacing.xl),
          Text(
            isSiswa ? 'Mulai dari sini' : 'Menu utama',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          if (isSiswa)
            _QuickGrid(
              items: [
                _QuickItem(
                  icon: Icons.search_rounded,
                  label: 'Cari Tutor',
                  onTap: () => context.go('/katalog'),
                ),
                _QuickItem(
                  icon: Icons.calendar_month_rounded,
                  label: 'Jadwal',
                  onTap: () => context.go('/jadwal'),
                ),
                _QuickItem(
                  icon: Icons.card_membership_rounded,
                  label: 'Paket Saya',
                  onTap: () => context.go('/paket'),
                ),
                _QuickItem(
                  icon: Icons.groups_rounded,
                  label: 'Kelas Grup',
                  onTap: () => context.go('/kelas-grup'),
                ),
              ],
            )
          else
            _QuickGrid(
              items: [
                _QuickItem(
                  icon: Icons.person_rounded,
                  label: 'Profil Saya',
                  onTap: () => context.go('/profil'),
                ),
                const _QuickItem(
                  icon: Icons.event_available_rounded,
                  label: 'Jadwal Mengajar',
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.isSiswa});

  final bool isSiswa;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      gradient: AppColors.gradient,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isSiswa ? 'Mau belajar apa\nhari ini?' : 'Siap mengajar\nhari ini?',
            style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            isSiswa
                ? 'Temukan tutor terbaik untukmu, dari SD sampai SMA.'
                : 'Kelola jadwal dan muridmu dari satu tempat.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: AppSpacing.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              ),
              onPressed: () => context.go(isSiswa ? '/katalog' : '/profil'),
              icon: Icon(isSiswa ? Icons.search_rounded : Icons.person_rounded),
              label: Text(isSiswa ? 'Cari Tutor' : 'Buka Profil'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickItem {
  const _QuickItem({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
}

class _QuickGrid extends StatelessWidget {
  const _QuickGrid({required this.items});
  final List<_QuickItem> items;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      final end = (i + 2 > items.length) ? items.length : i + 2;
      final pair = items.sublist(i, end);
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _QuickCard(item: pair[0])),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: pair.length > 1 ? _QuickCard(item: pair[1]) : const SizedBox(),
              ),
            ],
          ),
        ),
      );
      if (end < items.length) rows.add(const SizedBox(height: AppSpacing.md));
    }
    return Column(children: rows);
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({required this.item});
  final _QuickItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: item.onTap,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.lg,
        horizontal: AppSpacing.sm,
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
            child: Icon(item.icon, color: theme.colorScheme.primary, size: 24),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            item.label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
