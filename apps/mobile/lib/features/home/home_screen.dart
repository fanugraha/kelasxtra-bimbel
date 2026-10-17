import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_flavor.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/supabase_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_mode_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/section_head.dart';
import '../../widgets/screen_head.dart';
import '../../widgets/status_badge.dart';
import '../absensi_grup/absensi_grup_providers.dart';
import '../absensi_grup/absensi_grup_repository.dart';
import '../auth/auth_providers.dart';
import '../bank_soal/bank_soal_providers.dart';
import '../bank_soal/bank_soal_repository.dart';
import '../booking/booking_providers.dart';
import '../booking/booking_repository.dart';
import '../katalog/katalog_providers.dart';
import '../katalog/katalog_repository.dart';
import '../notifikasi/notifikasi_providers.dart';
import '../penghasilan/penghasilan_providers.dart';
import '../penghasilan/penghasilan_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flavor = ref.watch(appFlavorProvider);
    final isSiswa = flavor == AppFlavor.siswa;
    final profile = ref.watch(myProfileProvider).value;
    final bookings = ref.watch(jadwalProvider).value ?? const <BookingItem>[];
    final notifications =
        ref.watch(myNotificationsProvider).value ?? const [];
    final unread = notifications.any((n) => !n.read);

    final wrongRole = !isSiswa &&
        profile?.role != null &&
        profile!.role != 'tutor';
    final name = (profile?.fullName ?? supabase.auth.currentUser?.email ?? 'Kamu')
        .split(' ')
        .first;

    final now = DateTime.now();
    final upcoming = bookings
        .where((b) =>
            b.scheduledAt.isAfter(now.subtract(const Duration(minutes: 20))) &&
            !const {'completed', 'cancelled', 'expired', 'refunded'}
                .contains(b.status))
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(jadwalProvider);
            ref.invalidate(myStatsProvider);
            ref.invalidate(tutorListProvider);
            ref.invalidate(groupAttendanceProvider);
            ref.invalidate(myPayoutsProvider);
            ref.invalidate(myNotificationsProvider);
          },
          child: ListView(
            padding: screenPadding,
            children: [
              _HomeHead(
                name: name,
                isSiswa: isSiswa,
                unread: unread,
                subtitle: isSiswa
                    ? 'Siap lanjut belajar hari ini?'
                    : '${bookings.where((b) => _sameDay(b.scheduledAt, now)).length} sesi hari ini.',
              ),
              if (wrongRole) ...[
                const SizedBox(height: 16),
                AppCard(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Akun ini bukan tutor',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      const Text(
                          'Aplikasi ini untuk tutor. Keluar lalu masuk dengan akun tutor.'),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () =>
                            ref.read(authControllerProvider.notifier).signOut(),
                        child: const Text('Keluar'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              if (isSiswa) ...[
                const _PromoCarousel(),
                const SizedBox(height: 22),
                _StudentFocus(stats: ref.watch(myStatsProvider).value ?? const []),
                const SizedBox(height: 22),
                SectionHead(
                  title: 'Jadwal berikutnya',
                  actionLabel: 'Semua',
                  onAction: () => context.go('/jadwal'),
                ),
                const SizedBox(height: 9),
                if (upcoming.isEmpty)
                  const AppCard(
                    child: Text('Belum ada sesi terjadwal. Yuk cari tutor.'),
                  )
                else
                  _StudentSessionCard(booking: upcoming.first),
                const SizedBox(height: 22),
                _FeaturedTutors(
                  tutors: ref.watch(tutorListProvider).value ?? const [],
                ),
              ] else ...[
                _TutorHero(next: upcoming.isEmpty ? null : upcoming.first),
                const SizedBox(height: 12),
                _TutorStats(
                  bookings: bookings,
                  payouts: ref.watch(myPayoutsProvider).value ?? const [],
                ),
                const SizedBox(height: 22),
                SectionHead(
                  title: 'Jadwal terdekat',
                  actionLabel: 'Semua',
                  onAction: () => context.go('/jadwal'),
                ),
                const SizedBox(height: 9),
                if (upcoming.isEmpty)
                  const AppCard(child: Text('Belum ada sesi terjadwal.'))
                else
                  for (final b in upcoming.take(2)) ...[
                    _TutorSessionCard(booking: b),
                    const SizedBox(height: 8),
                  ],
                const SizedBox(height: 14),
                SectionHead(
                  title: 'Kelas grup',
                  actionLabel: 'Absensi',
                  onAction: () => context.go('/absensi-grup'),
                ),
                const SizedBox(height: 9),
                _TutorGroupCard(
                  rows: ref.watch(groupAttendanceProvider).value ?? const [],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _HomeHead extends ConsumerWidget {
  const _HomeHead({
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => context.go('/profil'),
          borderRadius: BorderRadius.circular(999),
          child: CircleAvatar(
            radius: 22,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.11),
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
              Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
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
              onTap: () => ref.read(themeModeProvider.notifier).toggle(context),
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
    );
  }
}

class _PromoCarousel extends StatefulWidget {
  const _PromoCarousel();

  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<_PromoCarousel> {
  final _controller = PageController(viewportFraction: 0.84);
  var _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = [
      _PromoData(
        kicker: 'Tryout · Matematika SMA',
        title: 'Uji kesiapanmu dalam 5 menit',
        meta: '5 soal contoh · dinilai otomatis',
        action: 'Mulai tryout',
        onTap: () => context.push('/tryout'),
        primary: true,
      ),
      _PromoData(
        kicker: 'Paket sesi',
        title: 'Tambah 8 sesi, hemat 5%',
        meta: 'Berlaku 90 hari · semua tutor',
        action: 'Lihat paket',
        onTap: () => context.push('/paket'),
      ),
      const _PromoData(
        kicker: 'Kelas grup',
        title: 'Belajar bareng teman',
        meta: 'Kuota 3–5 siswa · harga lebih ringan',
        action: 'Cari kelas',
      ),
    ];

    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _controller,
            itemCount: cards.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              final card = cards[i];
              return Padding(
                padding: EdgeInsets.only(right: i == cards.length - 1 ? 0 : 10),
                child: _PromoCard(
                  data: card,
                  onTap: card.onTap ?? () => context.push('/kelas-grup'),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < cards.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PromoData {
  const _PromoData({
    required this.kicker,
    required this.title,
    required this.meta,
    required this.action,
    this.onTap,
    this.primary = false,
  });

  final String kicker;
  final String title;
  final String meta;
  final String action;
  final VoidCallback? onTap;
  final bool primary;
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.data, required this.onTap});

  final _PromoData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = data.primary ? Colors.white : theme.colorScheme.onSurface;
    final muted = data.primary ? Colors.white70 : theme.colorScheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            gradient: data.primary ? AppColors.gradient : null,
            color: data.primary ? null : theme.colorScheme.surface,
            border: Border.all(
              color: data.primary ? Colors.transparent : theme.colorScheme.outline,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.kicker.toUpperCase(),
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: muted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                data.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: fg,
                  fontSize: 18.5,
                  height: 1.16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: muted),
              ),
              const Spacer(),
              Row(
                children: [
                  Text(
                    data.action,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: data.primary ? Colors.white : theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: data.primary ? Colors.white : theme.colorScheme.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentFocus extends StatelessWidget {
  const _StudentFocus({required this.stats});
  final List<TopicStat> stats;

  @override
  Widget build(BuildContext context) {
    final sorted = [...stats]..sort((a, b) => a.accuracy.compareTo(b.accuracy));
    final weak = sorted.isEmpty ? null : sorted.first;
    final strong = sorted.length < 2 ? null : sorted.last;

    return Column(
      children: [
        SectionHead(
          title: 'Kekuatan & kelemahan',
          actionLabel: 'Bank Soal',
          onAction: () => context.push('/bank-soal'),
        ),
        const SizedBox(height: 9),
        if (weak == null)
          AppCard(
            onTap: () => context.push('/bank-soal'),
            child: const Text('Latihan beberapa soal untuk melihat kekuatan dan kelemahanmu.'),
          )
        else ...[
          _TopicRow(stat: weak, strong: false),
          if (strong != null) ...[
            const SizedBox(height: 8),
            _TopicRow(stat: strong, strong: true),
          ],
        ],
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextLink(
            label: 'Kelas Grup · belajar bareng',
            icon: Icons.chevron_right_rounded,
            onTap: () => context.push('/kelas-grup'),
          ),
        ),
      ],
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.stat, required this.strong});
  final TopicStat stat;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = strong ? AppColors.success : AppColors.warning;
    final pct = stat.accuracy.round();

    return AppCard(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              strong ? Icons.check_rounded : Icons.priority_high_rounded,
              size: 19,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stat.topicName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${strong ? 'Kekuatan' : 'Kelemahan'} · akurasi $pct%',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: (stat.accuracy / 100).clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: theme.colorScheme.outline,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: () => context.push('/bank-soal'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
            child: Text(strong ? 'Lihat' : 'Latihan'),
          ),
        ],
      ),
    );
  }
}

class _StudentSessionCard extends StatelessWidget {
  const _StudentSessionCard({required this.booking});
  final BookingItem booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: () => context.push('/sesi/${booking.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ClockChip(date: booking.scheduledAt, minutes: booking.durationMinutes),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.tutorName, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${booking.subjectName} · ${booking.jenjang} · ${booking.durationMinutes} menit',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                    ),
                    const SizedBox(height: 6),
                    BookingBadge(status: booking.status),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(booking.mode == 'online'
                  ? Icons.videocam_outlined
                  : Icons.place_outlined, size: 16),
              const SizedBox(width: 5),
              Text(booking.mode == 'online' ? 'Online' : 'Offline',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
              const SizedBox(width: 14),
              const Icon(Icons.schedule_rounded, size: 16),
              const SizedBox(width: 5),
              Text(
                '${AppFormat.timeRangeFrom(booking.scheduledAt, booking.durationMinutes)} WIB',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.push('/sesi/${booking.id}'),
              child: const Text('Detail sesi'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClockChip extends StatelessWidget {
  const _ClockChip({required this.date, required this.minutes});
  final DateTime date;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          Text(AppFormat.dayLabel(date),
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              )),
          const SizedBox(height: 2),
          Text(AppFormat.hm(date),
              style: TextStyle(
                fontSize: 17,
                height: 1,
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              )),
          const SizedBox(height: 2),
          Text('$minutes mnt',
              style: TextStyle(fontSize: 8.5, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _FeaturedTutors extends StatelessWidget {
  const _FeaturedTutors({required this.tutors});
  final List<TutorCatalogItem> tutors;

  @override
  Widget build(BuildContext context) {
    if (tutors.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      children: [
        SectionHead(
          title: 'Tutor pilihan',
          actionLabel: 'Lihat semua',
          onAction: () => context.go('/katalog'),
        ),
        const SizedBox(height: 9),
        SizedBox(
          height: 164,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: tutors.take(6).length,
            separatorBuilder: (_, _) => const SizedBox(width: 9),
            itemBuilder: (context, i) {
              final t = tutors[i];
              return SizedBox(
                width: 188,
                child: AppCard(
                  onTap: () => context.push('/tutor/${t.id}'),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor:
                                theme.colorScheme.primary.withValues(alpha: 0.11),
                            child: Text(
                              t.fullName.isEmpty ? '?' : t.fullName[0].toUpperCase(),
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.fullName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall
                                        ?.copyWith(fontSize: 12.5)),
                                const SizedBox(height: 2),
                                Text(
                                  t.education ?? 'Tutor terverifikasi',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(fontSize: 10),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded,
                                        size: 14, color: AppColors.star),
                                    const SizedBox(width: 3),
                                    Text(t.ratingAvg.toStringAsFixed(1),
                                        style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text('Lihat profil dan jadwal',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontSize: 10.5)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TutorHero extends StatelessWidget {
  const _TutorHero({required this.next});
  final BookingItem? next;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SESI BERIKUTNYA',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: Colors.white.withValues(alpha: 0.8),
              )),
          const SizedBox(height: 7),
          Text(
            next == null
                ? 'Belum ada sesi berikutnya'
                : '${next!.subjectName} ${next!.jenjang} bersama ${next!.studentName}',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontSize: 24,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 9),
          if (next != null)
            Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 15, color: Colors.white70),
                const SizedBox(width: 5),
                Text(
                  '${AppFormat.dayLabel(next!.scheduledAt)} · ${AppFormat.timeRangeFrom(next!.scheduledAt, next!.durationMinutes)}',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 12),
                Icon(next!.mode == 'online'
                    ? Icons.videocam_outlined
                    : Icons.place_outlined, size: 15, color: Colors.white70),
                const SizedBox(width: 5),
                Text(next!.mode == 'online' ? 'Online' : 'Offline',
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          const SizedBox(height: 15),
          FilledButton.icon(
            onPressed: () => context.go('/jadwal'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryDark,
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text('Lihat jadwal'),
          ),
        ],
      ),
    );
  }
}

class _TutorStats extends StatelessWidget {
  const _TutorStats({required this.bookings, required this.payouts});
  final List<BookingItem> bookings;
  final List<PayoutItem> payouts;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = bookings.where((b) => _sameDay(b.scheduledAt, now)).toList();
    final needCheckIn = today
        .where((b) => b.status == 'confirmed')
        .length;
    final payoutTotal = payouts
        .where((p) => p.periodEnd.year == now.year && p.periodEnd.month == now.month)
        .fold<int>(0, (sum, p) => sum + p.amount);
    final completedThisMonth = bookings.where((b) =>
        b.status == 'completed' &&
        b.scheduledAt.year == now.year &&
        b.scheduledAt.month == now.month);
    final estimate = completedThisMonth.fold<int>(
      0,
      (sum, b) => sum + (b.price * 75 ~/ 100),
    );
    final monthTotal = payoutTotal > 0 ? payoutTotal : estimate;

    return Row(
      children: [
        Expanded(
          child: _Stat(
            label: 'Sesi hari ini',
            value: '${today.length}',
            note: '${today.where((b) => b.mode == 'online').length} online',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Stat(
            label: 'Perlu check-in',
            value: '$needCheckIn',
            note: 'status terkonfirmasi',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Stat(
            label: 'Bulan ini',
            value: AppFormat.rupiah(monthTotal),
            note: 'estimasi',
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.note});
  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 9.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 20, letterSpacing: -0.5)),
          ),
          const SizedBox(height: 3),
          Text(note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 9.5)),
        ],
      ),
    );
  }
}

class _TutorSessionCard extends StatelessWidget {
  const _TutorSessionCard({required this.booking});
  final BookingItem booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: () => context.push('/sesi/${booking.id}'),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ClockChip(date: booking.scheduledAt, minutes: booking.durationMinutes),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${booking.subjectName} · ${booking.studentName}',
                        style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${booking.jenjang} · ${booking.durationMinutes} menit',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              BookingBadge(status: booking.status),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.push('/sesi/${booking.id}'),
              child: const Text('Detail sesi'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorGroupCard extends StatelessWidget {
  const _TutorGroupCard({required this.rows});
  final List<GroupAttendanceRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (rows.isEmpty) {
      return const AppCard(child: Text('Belum ada kelas grup yang kamu ampu.'));
    }
    final first = rows.first;
    final sessionRows = rows.where((r) => r.sessionId == first.sessionId).toList();
    return AppCard(
      onTap: () => context.go('/absensi-grup'),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ClockChip(date: first.scheduledAt, minutes: 90),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(first.subjectName, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${sessionRows.length} siswa · ${first.mode == 'online' ? 'Online' : 'Offline'}',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const StatusBadge(label: 'Perlu absensi', tone: StatusTone.warning),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.go('/absensi-grup'),
              child: const Text('Buka absensi'),
            ),
          ),
        ],
      ),
    );
  }
}
