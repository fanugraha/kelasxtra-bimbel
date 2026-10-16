import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/home/home_screen.dart';
import '../features/katalog/katalog_screen.dart';
import '../features/katalog/tutor_detail_screen.dart';
import '../features/placeholder/placeholder_screen.dart';
import '../widgets/app_shell.dart';
import 'nav_destinations.dart';
import 'providers.dart';
import 'supabase_client.dart';

class _RefreshStream extends ChangeNotifier {
  _RefreshStream(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

Widget _screenFor(String path) => switch (path) {
      '/' => const HomeScreen(),
      '/katalog' => const KatalogScreen(),
      '/jadwal' => const PlaceholderScreen(
          title: 'Jadwal',
          icon: Icons.calendar_month_rounded,
          message: 'Jadwal sesimu akan tampil di sini.',
        ),
      '/profil' => const PlaceholderScreen(
          title: 'Profil',
          icon: Icons.person_rounded,
          message: 'Profil dan pengaturanmu akan tampil di sini.',
        ),
      _ => const HomeScreen(),
    };

final routerProvider = Provider<GoRouter>((ref) {
  final flavor = ref.watch(appFlavorProvider);
  final destinations = navDestinationsFor(flavor);

  final refresh = _RefreshStream(supabase.auth.onAuthStateChange);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = supabase.auth.currentSession != null;
      final loc = state.matchedLocation;
      final atAuth = loc == '/login' || loc == '/register';
      if (!loggedIn) return atAuth ? null : '/login';
      if (atAuth) return '/';
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(
          navigationShell: navigationShell,
          destinations: destinations,
        ),
        branches: [
          for (final d in destinations)
            StatefulShellBranch(
              routes: [
                GoRoute(path: d.path, builder: (c, s) => _screenFor(d.path)),
              ],
            ),
        ],
      ),
      GoRoute(
        path: '/tutor/:id',
        builder: (c, s) => TutorDetailScreen(tutorId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
    ],
  );
});
