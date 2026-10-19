import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_flavor.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/screen_head.dart';
import '../booking/booking_providers.dart';
import '../booking/booking_repository.dart';
import 'widgets/next_session_card.dart';
import 'widgets/session_tile.dart';

/// Agenda sesi siswa/tutor yang SUDAH LUNAS.
///
/// Susunannya meniru kartu janji temu Halodoc: sesi terdekat tampil sebagai
/// satu kartu besar (foto tentor + jadwal + aksi), lalu pertemuan berikutnya
/// sebagai timeline titik ke bawah yang dikelompokkan per tanggal.
class JadwalScreen extends ConsumerStatefulWidget {
  const JadwalScreen({super.key});

  @override
  ConsumerState<JadwalScreen> createState() => _JadwalScreenState();
}

class _JadwalScreenState extends ConsumerState<JadwalScreen> {
  var _completed = false;

  static const _closed = {'completed', 'cancelled', 'refunded', 'expired'};

  List<BookingItem> _agenda(List<BookingItem> all) {
    final list =
        all
            .where(
              (b) => _completed
                  ? b.status == 'completed'
                  : b.status != 'pending_payment' &&
                        !_closed.contains(b.status),
            )
            .toList()
          ..sort(
            (a, b) => _completed
                ? b.scheduledAt.compareTo(a.scheduledAt)
                : a.scheduledAt.compareTo(b.scheduledAt),
          );
    return list;
  }

  /// Kelompokkan sesi per tanggal; urutan mengikuti daftar yang sudah diurut.
  List<_DayGroup> _byDay(List<BookingItem> list) {
    final days = <DateTime, List<BookingItem>>{};
    for (final b in list) {
      final d = b.scheduledAt;
      days.putIfAbsent(DateTime(d.year, d.month, d.day), () => []).add(b);
    }
    return [
      for (final e in days.entries) _DayGroup(day: e.key, items: e.value),
    ];
  }

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
            final list = _agenda(all);
            final hasUnpaid =
                isSiswa && all.any((b) => b.status == 'pending_payment');
            final next = !_completed && list.isNotEmpty ? list.first : null;
            final rest = next == null ? list : list.skip(1).toList();
            final groups = _byDay(rest);

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(jadwalProvider),
              child: ListView(
                padding: screenPadding,
                children: [
                  ScreenHead(
                    eyebrow: isSiswa ? 'Agenda' : 'Agenda mengajar',
                    title: 'Jadwal',
                    subtitle: isSiswa
                        ? 'Sesi yang sudah dibayar, urut dari yang terdekat.'
                        : 'Sesi mengajar, urut dari yang terdekat.',
                  ),
                  const SizedBox(height: 18),
                  _Segmented(
                    left: isSiswa ? 'Akan datang' : 'Hari ini',
                    right: 'Selesai',
                    rightSelected: _completed,
                    onChanged: (v) => setState(() => _completed = v),
                  ),
                  const SizedBox(height: 18),
                  if (hasUnpaid && !_completed) ...[
                    const _UnpaidBanner(),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (list.isEmpty)
                    EmptyState(
                      icon: Icons.event_busy_rounded,
                      title: _completed
                          ? 'Belum ada sesi selesai'
                          : 'Belum ada jadwal',
                      message: _completed
                          ? 'Sesi yang sudah berjalan akan tampil di sini.'
                          : isSiswa
                          ? 'Pilih tutor favoritmu, lalu beli paket pertemuannya.'
                          : 'Belum ada sesi yang dijadwalkan untukmu.',
                      action: isSiswa && !_completed
                          ? FilledButton.icon(
                              onPressed: () => context.go('/katalog'),
                              icon: const Icon(Icons.search_rounded),
                              label: const Text('Cari Tutor'),
                            )
                          : null,
                    )
                  else ...[
                    if (next != null) ...[
                      const _SectionLabel(
                        icon: Icons.bolt_rounded,
                        text: 'Sesi berikutnya',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      NextSessionCard(booking: next, isSiswa: isSiswa),
                      const SizedBox(height: AppSpacing.xxl),
                    ],
                    if (groups.isNotEmpty) ...[
                      _SectionLabel(
                        icon: _completed
                            ? Icons.history_rounded
                            : Icons.event_repeat_rounded,
                        text: _completed ? 'Riwayat sesi' : 'Jadwal berikutnya',
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      for (final group in groups)
                        _DayGroupView(
                          group: group,
                          isSiswa: isSiswa,
                          muted: _completed,
                        ),
                    ],
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

class _DayGroup {
  const _DayGroup({required this.day, required this.items});

  final DateTime day;
  final List<BookingItem> items;
}

/// Satu tanggal di timeline: judul hari + deretan titik sesi.
class _DayGroupView extends StatelessWidget {
  const _DayGroupView({
    required this.group,
    required this.isSiswa,
    required this.muted,
  });

  final _DayGroup group;
  final bool isSiswa;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DayHead(day: group.day, count: group.items.length),
          const SizedBox(height: 2),
          for (var i = 0; i < group.items.length; i++)
            SessionTile(
              booking: group.items[i],
              isSiswa: isSiswa,
              isFirst: i == 0,
              isLast: i == group.items.length - 1,
              muted: muted,
            ),
        ],
      ),
    );
  }
}

class _DayHead extends StatelessWidget {
  const _DayHead({required this.day, required this.count});

  final DateTime day;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = AppFormat.dayLabel(day);
    final soon = label == 'Hari ini' || label == 'Besok';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: soon ? scheme.primary : scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count sesi',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: scheme.primary),
        const SizedBox(width: 6),
        Text(
          text,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget item(String label, bool selected, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? scheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.22),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(999),
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
