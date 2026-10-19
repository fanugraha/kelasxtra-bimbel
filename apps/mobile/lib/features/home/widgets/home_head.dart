import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../core/widgets/screen_head.dart';

/// Kepala halaman home: avatar, sapaan, tombol tema & notifikasi.
class HomeHead extends ConsumerWidget {
  const HomeHead({
    super.key,
    required this.name,
    required this.isSiswa,
    required this.unread,
    required this.subtitle,
  });

  final String name;
  final bool isSiswa;
  final bool unread;
  final String subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () =>
                isSiswa ? context.go('/profil') : context.push('/profil'),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              // Avatar inisial: tonal brand, bukan blok warna penuh.
              decoration: BoxDecoration(
                color: palette.brandSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                initial,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: palette.brand,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hai, $name 👋',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!isSiswa) ...[
            IconAction(
              icon: Icons.notifications_none_rounded,
              tooltip: 'Notifikasi',
              dot: unread,
              onTap: () => context.push('/notifikasi'),
            ),
            const SizedBox(width: 6),
          ],
          Consumer(
            builder: (context, ref, _) {
              ref.watch(themeModeProvider);
              final dark = ref.read(themeModeProvider.notifier).isDark(context);
              return IconAction(
                icon: dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                tooltip: dark ? 'Mode terang' : 'Mode gelap',
                onTap: () =>
                    ref.read(themeModeProvider.notifier).toggle(context),
              );
            },
          ),
          if (isSiswa) ...[
            const SizedBox(width: 6),
            IconAction(
              icon: Icons.notifications_none_rounded,
              tooltip: 'Notifikasi',
              dot: unread,
              onTap: () => context.push('/notifikasi'),
            ),
          ],
        ],
      ),
    );
  }
}
