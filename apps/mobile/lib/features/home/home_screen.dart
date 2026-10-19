import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/dates.dart';

import '../../core/app_flavor.dart';
import '../../core/providers.dart';
import '../../core/supabase_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/screen_head.dart';
import '../absensi_grup/absensi_grup_providers.dart';
import '../auth/auth_providers.dart';
import '../bank_soal/bank_soal_providers.dart';
import '../booking/booking_providers.dart';
import '../booking/booking_repository.dart';
import '../katalog/katalog_providers.dart';
import '../notifikasi/notifikasi_providers.dart';
import '../penghasilan/penghasilan_providers.dart';
import 'home_utils.dart';
import 'siswa/home_siswa_view.dart';
import 'tutor/home_tutor_view.dart';
import 'widgets/home_head.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flavor = ref.watch(appFlavorProvider);
    final isSiswa = flavor == AppFlavor.siswa;
    final profile = ref.watch(myProfileProvider).value;
    final bookings = ref.watch(jadwalProvider).value ?? const <BookingItem>[];
    final notifications = ref.watch(myNotificationsProvider).value ?? const [];
    final unread = notifications.any((n) => !n.read);

    final wrongRole =
        !isSiswa && profile?.role != null && profile!.role != 'tutor';
    final name =
        (profile?.fullName ?? supabase.auth.currentUser?.email ?? 'Kamu')
            .split(' ')
            .first;

    final now = DateTime.now();
    final upcoming = upcomingBookings(bookings);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(jadwalProvider);
            ref.invalidate(myStatsProvider);
            ref.invalidate(featuredTutorsProvider);
            ref.invalidate(groupAttendanceProvider);
            ref.invalidate(myPayoutsProvider);
            ref.invalidate(myNotificationsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 36),
            children: [
              sidePad(
                HomeHead(
                  name: name,
                  isSiswa: isSiswa,
                  unread: unread,
                  subtitle: isSiswa
                      ? 'Siap lanjut belajar hari ini?'
                      : '${bookings.where((b) => isSameDay(b.scheduledAt, now)).length} sesi hari ini.',
                ),
              ),
              if (wrongRole) ...[
                const SizedBox(height: 16),
                sidePad(
                  AppCard(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Akun ini bukan tutor',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Aplikasi ini untuk tutor. Keluar lalu masuk dengan akun tutor.',
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => ref
                              .read(authControllerProvider.notifier)
                              .signOut(),
                          child: const Text('Keluar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              if (isSiswa)
                HomeSiswaView(upcoming: upcoming)
              else
                HomeTutorView(bookings: bookings, upcoming: upcoming),
            ],
          ),
        ),
      ),
    );
  }
}
