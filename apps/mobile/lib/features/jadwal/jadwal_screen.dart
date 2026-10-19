import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_flavor.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/screen_head.dart';
import '../booking/booking_providers.dart';
import '../booking/booking_repository.dart';
import 'widgets/session_card.dart';

/// Agenda sesi siswa/tutor: yang akan datang dan yang sudah selesai.
/// Riwayat uang (paket, sesi, langganan) ada di halaman Riwayat transaksi.
class JadwalScreen extends ConsumerStatefulWidget {
  const JadwalScreen({super.key});

  @override
  ConsumerState<JadwalScreen> createState() => _JadwalScreenState();
}

class _JadwalScreenState extends ConsumerState<JadwalScreen> {
  var _completed = false;

  /// Kelompok Lapis 1 yang sedang ditutup (per id tentor/siswa).
  final _collapsed = <String>{};

  /// Sesi mendatang: semua yang belum tuntas/dibatalkan. Sesi lampau:
  /// yang sudah selesai — dipisah agar agenda tetap ringkas.
  List<BookingItem> _agenda(List<BookingItem> all) {
    final list =
        all
            .where(
              (b) => _completed
                  ? b.status == 'completed'
                  : b.status != 'completed' &&
                        b.status != 'cancelled' &&
                        b.status != 'refunded' &&
                        b.status != 'expired',
            )
            .toList()
          ..sort(
            (a, b) => _completed
                ? b.scheduledAt.compareTo(a.scheduledAt)
                : a.scheduledAt.compareTo(b.scheduledAt),
          );
    return list;
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

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(jadwalProvider),
              child: ListView(
                padding: screenPadding,
                children: [
                  ScreenHead(
                    eyebrow: isSiswa ? 'Agenda' : 'Agenda mengajar',
                    title: 'Jadwal',
                    subtitle: isSiswa
                        ? 'Dikelompokkan per tentor. Ketuk untuk buka daftar sesinya. Waktu memakai WIB.'
                        : 'Dikelompokkan per siswa. Sesi privat dan kelas grup yang harus kamu ajar.',
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
                      title: _completed
                          ? 'Belum ada sesi selesai'
                          : 'Belum ada sesi',
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
                  else
                    ..._grouped(list, isSiswa),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Dua lapis: Lapis 1 kartu tentor (atau siswa, bila kita tutor) dan
  /// Lapis 2 daftar jadwal milik orang itu. Urutan sesi tetap kronologis.
  List<Widget> _grouped(List<BookingItem> list, bool isSiswa) {
    final groups = <String, _PersonGroup>{};
    for (final b in list) {
      final key = isSiswa ? b.tutorId : b.studentId;
      final group = groups.putIfAbsent(
        key,
        () => _PersonGroup(
          id: key,
          name: isSiswa ? b.tutorName : b.studentName,
          photoUrl: isSiswa ? b.tutorPhotoUrl : null,
        ),
      );
      group.items.add(b);
    }

    return [
      for (final group in groups.values) ...[
        _PersonCard(
          group: group,
          isSiswa: isSiswa,
          collapsed: _collapsed.contains(group.id),
          onToggle: () => setState(() {
            if (!_collapsed.remove(group.id)) _collapsed.add(group.id);
          }),
        ),
        if (!_collapsed.contains(group.id))
          for (final b in group.items)
            Padding(
              padding: const EdgeInsets.only(left: 14, top: AppSpacing.sm + 2),
              child: SessionCard(booking: b, isSiswa: isSiswa),
            ),
        const SizedBox(height: AppSpacing.md),
      ],
    ];
  }
}

/// Satu kelompok Lapis 1: tentor (dilihat siswa) atau siswa (dilihat tutor).
class _PersonGroup {
  _PersonGroup({required this.id, required this.name, this.photoUrl});

  final String id;
  final String name;
  final String? photoUrl;
  final items = <BookingItem>[];
}

/// Kartu Lapis 1: foto/inisial, nama, ringkasan mapel & jumlah sesi, lalu
/// tombol buka-tutup daftar jadwalnya.
class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.group,
    required this.isSiswa,
    required this.collapsed,
    required this.onToggle,
  });

  final _PersonGroup group;
  final bool isSiswa;
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final initial = group.name.isEmpty ? '?' : group.name[0].toUpperCase();
    final subjects = <String>{
      for (final b in group.items) b.subjectName,
    }.join(', ');
    final photo = group.photoUrl;
    final nearest = group.items.first.scheduledAt;

    return AppCard(
      onTap: onToggle,
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      child: Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: scheme.primary.withValues(alpha: 0.12),
            backgroundImage: photo == null ? null : NetworkImage(photo),
            child: photo == null
                ? Text(
                    initial,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${isSiswa ? 'Tutor' : 'Siswa'} ${group.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 14.5),
                ),
                const SizedBox(height: 3),
                Text(
                  '${group.items.length} sesi · $subjects',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                ),
                const SizedBox(height: 1),
                Text(
                  '${collapsed ? 'Berikutnya' : 'Mulai'}: ${AppFormat.dateShort(nearest)} · '
                  '${AppFormat.hm(nearest)} WIB',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            collapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded,
            color: scheme.onSurfaceVariant,
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
