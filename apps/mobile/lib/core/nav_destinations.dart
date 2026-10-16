import 'package:flutter/material.dart';

import 'app_flavor.dart';

/// Satu tab di bottom navigation.
class NavDest {
  const NavDest({
    required this.path,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Tab bottom-navigation per flavor. Urutan = urutan cabang di router.
/// Maks 5 tab agar tetap nyaman dijangkau jempol.
List<NavDest> navDestinationsFor(AppFlavor flavor) => switch (flavor) {
      AppFlavor.siswa => const [
          NavDest(
            path: '/',
            label: 'Beranda',
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
          ),
          NavDest(
            path: '/katalog',
            label: 'Cari',
            icon: Icons.search_outlined,
            activeIcon: Icons.search_rounded,
          ),
          NavDest(
            path: '/jadwal',
            label: 'Jadwal',
            icon: Icons.calendar_today_outlined,
            activeIcon: Icons.calendar_month_rounded,
          ),
          NavDest(
            path: '/profil',
            label: 'Profil',
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
          ),
        ],
      AppFlavor.tutor => const [
          NavDest(
            path: '/',
            label: 'Beranda',
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
          ),
          NavDest(
            path: '/profil',
            label: 'Profil',
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
          ),
        ],
    };
