import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_flavor.dart';
import '../../core/providers.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/screen_head.dart';
import '../booking/booking_providers.dart';
import '../booking/booking_repository.dart';
import 'jadwal_grouping.dart';
import 'widgets/person_card.dart';
import 'widgets/up_next_card.dart';
import 'widgets/week_strip.dart';

/// Langkah pertama Jadwal: daftar tutor (aplikasi siswa) atau siswa
/// (aplikasi tutor) yang punya sesi LUNAS, urut dari sesi yang paling dekat.
/// Ketuk satu orang → detail kelas bersamanya (`/jadwal/:personId`).
class JadwalScreen extends ConsumerWidget {
  const JadwalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(jadwalProvider);
    final isSiswa = ref.watch(appFlavorProvider) == AppFlavor.siswa;

    return Scaffold(
      body: SafeArea(
        child: AsyncView<List<BookingItem>>(
          value: bookings,
          errorTitle: 'Gagal memuat jadwal',
          onRetry: () => ref.invalidate(jadwalProvider),
          builder: (all) {
            final people = groupJadwal(all, isSiswa: isSiswa);
            final hasUnpaid =
                isSiswa && all.any((b) => b.status == 'pending_payment');
            final active = people.where((p) => p.next != null).toList();
            final past = people.where((p) => p.next == null).toList();
            // Semua sesi mendatang lintas tutor, urut terdekat.
            final upcoming = [for (final p in people) ...p.upcoming]
              ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
            final next = upcoming.firstOrNull;

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(jadwalProvider),
              child: ListView(
                padding: screenPadding,
                children: [
                  ScreenHead(
                    title: 'Jadwal',
                    subtitle: isSiswa
                        ? 'Sesi terdekatmu, lalu daftar tutor & kelasnya.'
                        : 'Sesi terdekat, lalu daftar siswa & kelasnya.',
                  ),
                  const SizedBox(height: 18),
                  if (hasUnpaid) ...[
                    const _UnpaidBanner(),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (people.isEmpty)
                    EmptyState(
                      icon: Icons.event_busy_rounded,
                      title: 'Belum ada jadwal',
                      message: isSiswa
                          ? 'Pilih tutor favoritmu, lalu beli paket pertemuannya.'
                          : 'Belum ada sesi yang dijadwalkan untukmu.',
                      action: isSiswa
                          ? FilledButton.icon(
                              onPressed: () => context.go('/katalog'),
                              icon: const Icon(Icons.search_rounded),
                              label: const Text('Cari Tutor'),
                            )
                          : null,
                    )
                  else ...[
                    if (next != null) ...[
                      UpNextCard(booking: next, isSiswa: isSiswa),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    WeekStrip(upcoming: upcoming),
                    const SizedBox(height: AppSpacing.xl),
                    if (active.isNotEmpty)
                      _PeopleSection(
                        icon: Icons.bolt_rounded,
                        title: isSiswa ? 'Tutor aktif' : 'Siswa aktif',
                        people: active,
                        isSiswa: isSiswa,
                      ),
                    if (active.isNotEmpty && past.isNotEmpty)
                      const SizedBox(height: AppSpacing.xl),
                    if (past.isNotEmpty)
                      _PeopleSection(
                        icon: Icons.history_rounded,
                        title: 'Kelas sebelumnya',
                        people: past,
                        isSiswa: isSiswa,
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PeopleSection extends StatelessWidget {
  const _PeopleSection({
    required this.icon,
    required this.title,
    required this.people,
    required this.isSiswa,
  });

  final IconData icon;
  final String title;
  final List<JadwalPerson> people;
  final bool isSiswa;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: scheme.primary),
            const SizedBox(width: 6),
            Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Text('${people.length}', style: theme.textTheme.labelSmall),
          ],
        ),
        const SizedBox(height: AppSpacing.sm + 2),
        for (var i = 0; i < people.length; i++) ...[
          PersonCard(
            person: people[i],
            isSiswa: isSiswa,
            onTap: () => context.push('/jadwal/${people[i].id}'),
          ),
          if (i < people.length - 1) const SizedBox(height: AppSpacing.sm + 2),
        ],
      ],
    );
  }
}

/// Pengingat tagihan yang belum dibayar; detailnya di Riwayat transaksi.
class _UnpaidBanner extends StatelessWidget {
  const _UnpaidBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return AppCard(
      onTap: () => context.push('/riwayat-transaksi'),
      // Warna: tagihan menggantung perlu perhatian → peringatan tonal.
      color: palette.warningSoft,
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      child: Row(
        children: [
          Icon(Icons.receipt_long_rounded, color: palette.warning),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ada pembayaran yang belum selesai',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'Jadwalnya baru muncul di sini setelah lunas. Lihat di Riwayat transaksi.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
