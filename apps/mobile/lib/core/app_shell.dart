import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/chat/chat_notifier.dart';
import '../features/chat/chat_providers.dart';
import 'nav_destinations.dart';
import 'theme/app_colors.dart';
import 'theme/app_palette.dart';

/// Cangkang aplikasi dengan bottom navigation bergaya "My Diary":
/// bilah putih melengkung dengan tombol tengah menonjol.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.destinations,
  });

  final StatefulNavigationShell navigationShell;
  final List<NavDest> destinations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(chatUnreadProvider);
    return Scaffold(
      // Area di atas bilah (tempat tombol tengah menonjol) harus transparan;
      // tanpa ini Scaffold mengecatnya dengan warna latar → kotak janggal.
      extendBody: true,
      body: ChatInboxWatcher(child: navigationShell),
      bottomNavigationBar: _MyDiaryNavBar(
        destinations: destinations,
        currentIndex: navigationShell.currentIndex,
        unread: unread,
        onTap: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

class _MyDiaryNavBar extends StatelessWidget {
  const _MyDiaryNavBar({
    required this.destinations,
    required this.currentIndex,
    required this.unread,
    required this.onTap,
  });

  final List<NavDest> destinations;
  final int currentIndex;
  final int unread;
  final ValueChanged<int> onTap;

  static const _barHeight = 68.0;
  static const _orbSize = 58.0;
  static const _orbOverhang = 18.0;

  /// Jarak rata antara tombol tengah dan tepi lekukan.
  static const _notchGap = 6.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final totalHeight = _orbOverhang + _barHeight + bottomInset;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _barHeight + bottomInset,
            child: PhysicalShape(
              color: scheme.surface,
              elevation: 18,
              shadowColor: Colors.black.withValues(alpha: 0.16),
              // Lekukan sepusat dengan tombol tengah (bukan di tepi atas bilah).
              clipper: const _NotchClipper(
                radius: _orbSize / 2 + _notchGap,
                centerY: _orbSize / 2 - _orbOverhang,
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: Row(
                  children: [
                    for (var i = 0; i < destinations.length; i++)
                      Expanded(
                        child: i == destinations.length ~/ 2
                            ? const SizedBox.shrink()
                            : _NavItem(
                                dest: destinations[i],
                                selected: currentIndex == i,
                                badge: destinations[i].path == '/chat'
                                    ? unread
                                    : 0,
                                onTap: () => onTap(i),
                              ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: _CenterOrb(
                dest: destinations[destinations.length ~/ 2],
                selected: currentIndex == destinations.length ~/ 2,
                size: _orbSize,
                onTap: () => onTap(destinations.length ~/ 2),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset + 8,
            child: IgnorePointer(
              child: Text(
                destinations[destinations.length ~/ 2].label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: currentIndex == destinations.length ~/ 2
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: currentIndex == destinations.length ~/ 2
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.dest,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final NavDest dest;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;

    return Semantics(
      selected: selected,
      button: true,
      label: dest.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  selected ? dest.activeIcon : dest.icon,
                  size: 23,
                  color: color,
                ),
                if (badge > 0)
                  Positioned(
                    top: -5,
                    right: -10,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 17),
                      height: 17,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.error,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: scheme.surface, width: 1.5),
                      ),
                      child: Text(
                        badge > 9 ? '9+' : '$badge',
                        // Hitungan unread di badge 17px: 11 agar muat
                        // (pengecualian batas minimum 12).
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          height: 1.1,
                          letterSpacing: 0,
                          fontWeight: FontWeight.w600,
                          color: scheme.onError,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              dest.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterOrb extends StatelessWidget {
  const _CenterOrb({
    required this.dest,
    required this.selected,
    required this.size,
    required this.onTap,
  });

  final NavDest dest;
  final bool selected;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: dest.label,
      // Bayangan di DecoratedBox luar; efek sentuh di Material bulat yang
      // memotong isinya — supaya tidak ada sisa bayangan/ripple berbentuk kotak.
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: context.palette.brand.withValues(alpha: 0.30),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: AppColors.gradient,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.55),
                width: selected ? 3 : 2,
              ),
            ),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Icon(
                selected ? dest.activeIcon : dest.icon,
                size: 26,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Memotong lingkaran di tengah atas bilah untuk tombol menonjol.
/// [centerY] = posisi pusat tombol relatif terhadap tepi atas bilah.
class _NotchClipper extends CustomClipper<Path> {
  const _NotchClipper({required this.radius, required this.centerY});

  final double radius;
  final double centerY;

  @override
  Path getClip(Size size) {
    final bar = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final notch = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width / 2, centerY),
          radius: radius,
        ),
      );
    return Path.combine(PathOperation.difference, bar, notch);
  }

  @override
  bool shouldReclip(_NotchClipper oldClipper) =>
      oldClipper.radius != radius || oldClipper.centerY != centerY;
}
