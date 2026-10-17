import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_flavor.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/screen_head.dart';
import '../../widgets/status_badge.dart';
import '../booking/booking_providers.dart';
import '../booking/booking_repository.dart';

class JadwalScreen extends ConsumerStatefulWidget {
  const JadwalScreen({super.key});

  @override
  ConsumerState<JadwalScreen> createState() => _JadwalScreenState();
}

class _JadwalScreenState extends ConsumerState<JadwalScreen> {
  var _completed = false;

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(jadwalProvider);
    final isSiswa = ref.watch(appFlavorProvider) == AppFlavor.siswa;

    return Scaffold(
      body: SafeArea(
        child: AsyncView<List<BookingItem>>(
          value: bookings,
          errorTitle: 'Gagal memuat jadwal',
          onRetry: () => ref.invalidate(jadwalProvider),
          builder: (all) {
            final list = all
                .where((b) =>
                    _completed
                        ? b.status == 'completed' || b.status == 'refunded'
                        : b.status != 'completed' &&
                            b.status != 'cancelled' &&
                            b.status != 'refunded' &&
                            b.status != 'expired')
                .toList()
              ..sort((a, b) => _completed
                  ? b.scheduledAt.compareTo(a.scheduledAt)
                  : a.scheduledAt.compareTo(b.scheduledAt));

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(jadwalProvider),
              child: ListView(
                padding: screenPadding,
                children: [
                  ScreenHead(
                    eyebrow: isSiswa ? 'Agenda' : 'Agenda mengajar',
                    title: 'Jadwal',
                    subtitle: isSiswa
                        ? 'Sesi terbaru selalu muncul paling atas. Waktu memakai WIB.'
                        : 'Sesi privat dan kelas grup yang harus kamu ajar.',
                  ),
                  const SizedBox(height: 18),
                  _Segmented(
                    left: isSiswa ? 'Akan datang' : 'Hari ini',
                    right: 'Selesai',
                    rightSelected: _completed,
                    onChanged: (v) => setState(() => _completed = v),
                  ),
                  const SizedBox(height: 18),
                  if (list.isEmpty)
                    EmptyState(
                      icon: Icons.event_busy_rounded,
                      title: _completed ? 'Belum ada sesi selesai' : 'Belum ada sesi',
                      message: isSiswa
                          ? 'Yuk cari tutor dan pesan sesi pertamamu.'
                          : 'Belum ada sesi yang dijadwalkan untukmu.',
                      action: isSiswa
                          ? FilledButton.icon(
                              onPressed: () => context.go('/katalog'),
                              icon: const Icon(Icons.search_rounded),
                              label: const Text('Cari Tutor'),
                            )
                          : null,
                    )
                  else
                    for (final b in list) ...[
                      _BookingCard(booking: b, isSiswa: isSiswa),
                      const SizedBox(height: 9),
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

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.isSiswa});
  final BookingItem booking;
  final bool isSiswa;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final person = isSiswa ? booking.tutorName : booking.studentName;
    final initial = person.isEmpty ? '?' : person[0].toUpperCase();

    return AppCard(
      onTap: () => context.push('/sesi/${booking.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(AppFormat.dayLabel(booking.scheduledAt),
                        style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: scheme.primary)),
                    const SizedBox(height: 1),
                    Text(AppFormat.hm(booking.scheduledAt),
                        style: TextStyle(
                            fontSize: 17,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            color: scheme.primary)),
                  ],
                ),
              ),
              const SizedBox(width: 11),
              CircleAvatar(
                radius: 19,
                backgroundColor: scheme.primary.withValues(alpha: 0.10),
                child: Text(initial,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: scheme.primary)),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(person,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${booking.subjectName} · ${booking.jenjang} · ${booking.durationMinutes} menit',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              BookingBadge(status: booking.status),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Icon(
                booking.mode == 'online'
                    ? Icons.videocam_outlined
                    : Icons.place_outlined,
                size: 16,
              ),
              const SizedBox(width: 5),
              Text(
                booking.mode == 'online' ? 'Online' : 'Offline',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.schedule_rounded, size: 16),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${AppFormat.timeRangeFrom(booking.scheduledAt, booking.durationMinutes)} WIB',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push('/sesi/${booking.id}'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    textStyle: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w800),
                  ),
                  child: Text(booking.status == 'completed' ? 'Beri ulasan' : 'Detail sesi'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton(
                  onPressed: () => context.push('/sesi/${booking.id}'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    textStyle: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w800),
                  ),
                  child: const Text('Chat'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.left,
    required this.right,
    required this.rightSelected,
    required this.onChanged,
  });

  final String left;
  final String right;
  final bool rightSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget item(String label, bool selected, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? scheme.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.04),
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          item(left, !rightSelected, () => onChanged(false)),
          item(right, rightSelected, () => onChanged(true)),
        ],
      ),
    );
  }
}
