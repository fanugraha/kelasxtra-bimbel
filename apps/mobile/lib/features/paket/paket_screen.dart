import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/screen_head.dart';
import 'paket_providers.dart';
import 'paket_repository.dart';
import 'widgets/package_card.dart';

class PaketScreen extends ConsumerWidget {
  const PaketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packages = ref.watch(myPackagesProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(myPackagesProvider),
          child: ListView(
            padding: screenPadding,
            children: [
              const ScreenHead(
                showBack: true,
                eyebrow: 'Paket belajar',
                title: 'Paket Saya',
                subtitle: 'Satu paket berisi 4–12 pertemuan, seminggu sekali.',
              ),
              const SizedBox(height: AppSpacing.xl),
              AsyncView<List<PackageItem>>(
                value: packages,
                errorTitle: 'Gagal memuat paket',
                onRetry: () => ref.invalidate(myPackagesProvider),
                builder: (list) => list.isEmpty
                    ? EmptyState(
                        icon: Icons.card_membership_rounded,
                        title: 'Belum ada paket',
                        message: 'Pilih tutor, lalu beli paket pertemuannya.',
                        action: FilledButton.icon(
                          onPressed: () => context.go('/katalog'),
                          icon: const Icon(Icons.search_rounded),
                          label: const Text('Cari Tutor'),
                        ),
                      )
                    : Column(
                        children: [
                          for (final item in list) ...[
                            PackageCard(item: item),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          const SizedBox(height: AppSpacing.xs),
                          OutlinedButton.icon(
                            onPressed: () => context.go('/katalog'),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Beli paket tutor lain'),
                          ),
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
