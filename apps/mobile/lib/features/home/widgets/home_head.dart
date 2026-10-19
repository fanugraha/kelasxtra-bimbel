import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
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

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () =>
                isSiswa ? context.go('/profil') : context.push('/profil'),
            borderRadius: BorderRadius.circular(999),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: theme.colorScheme.primary.withValues(
                alpha: 0.11,
              ),
              child: Text(
                initial,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
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
                  AppFormat.dateLong(DateTime.now()),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Hai, $name 👋',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: 23,
                    height: 1.12,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
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
