import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/absensi_grup/absensi_grup_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/profil_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/bank_soal/bank_soal_screen.dart';
import '../features/bank_soal/latihan_screen.dart';
import '../features/booking/booking_detail_screen.dart';
import '../features/booking/booking_screen.dart';
import '../features/home/home_screen.dart';
import '../features/jadwal/jadwal_screen.dart';
import '../features/kelas_grup/kelas_grup_detail_screen.dart';
import '../features/kelas_grup/kelas_grup_screen.dart';
import '../features/katalog/katalog_screen.dart';
import '../features/notifikasi/notifikasi_screen.dart';
import '../features/katalog/tutor_detail_screen.dart';
import '../features/paket/beli_paket_screen.dart';
import '../features/penghasilan/penghasilan_screen.dart';
import '../features/paket/paket_screen.dart';
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
      '/jadwal' => const JadwalScreen(),
      '/absensi-grup' => const AbsensiGrupScreen(),
      '/penghasilan' => const PenghasilanScreen(),
      '/profil' => const ProfilScreen(),
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
      GoRoute(
        path: '/booking/:id',
        builder: (c, s) => BookingScreen(tutorId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/notifikasi',
        builder: (c, s) => const NotifikasiScreen(),
      ),
      GoRoute(
        path: '/sesi/:id',
        builder: (c, s) => BookingDetailScreen(bookingId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/paket', builder: (c, s) => const PaketScreen()),
      GoRoute(
        path: '/paket/beli/:id',
        builder: (c, s) => BeliPaketScreen(tutorId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/kelas-grup', builder: (c, s) => const KelasGrupScreen()),
      GoRoute(
        path: '/kelas-grup/:id',
        builder: (c, s) => KelasGrupDetailScreen(classId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/bank-soal', builder: (c, s) => const BankSoalScreen()),
      GoRoute(
        path: '/tryout',
        builder: (c, s) {
          final extra = (s.extra as Map?) ?? const {};
          return LatihanScreen(
            topicId: null,
            topicName: 'Tryout',
            jenjang: extra['jenjang'] as String?,
            count: 20,
            mode: 'tryout',
            durationMinutes: 20,
          );
        },
      ),
      GoRoute(
        path: '/latihan/:topicId',
        builder: (c, s) {
          final extra = (s.extra as Map?) ?? const {};
          return LatihanScreen(
            topicId: s.pathParameters['topicId']!,
            topicName: (extra['name'] ?? 'Latihan') as String,
            jenjang: extra['jenjang'] as String?,
          );
        },
      ),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
    ],
  );
});
