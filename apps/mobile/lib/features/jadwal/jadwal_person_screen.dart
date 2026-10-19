import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_flavor.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/screen_head.dart';
import '../booking/booking_providers.dart';
import '../booking/booking_repository.dart';
import 'jadwal_grouping.dart';
import 'widgets/lesson_tile.dart';
import 'widgets/next_session_card.dart';
import 'widgets/person_hero.dart';
import 'widgets/segmented_tabs.dart';
import 'widgets/stat_tiles.dart';

/// Langkah kedua Jadwal: detail kelas bersama satu tutor (atau satu siswa di
/// aplikasi tutor) — ringkasan angka, jadwal mendatang, dan riwayat kelas.
/// Ketuk satu sesi untuk catatan, tautan kelas, dan aksinya (`/sesi/:id`).
class JadwalPersonScreen extends ConsumerStatefulWidget {
  const JadwalPersonScreen({super.key, required this.personId});

  final String personId;

  @override
  ConsumerState<JadwalPersonScreen> createState() => _JadwalPersonScreenState();
}

class _JadwalPersonScreenState extends ConsumerState<JadwalPersonScreen> {
  var _history = false;

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(jadwalProvider);
    final isSiswa = ref.watch(appFlavorProvider) == AppFlavor.siswa;

    return Scaffold(
      body: AsyncView<List<BookingItem>>(
        value: bookings,
        errorTitle: 'Gagal memuat kelas',
        onRetry: () => ref.invalidate(jadwalProvider),
        builder: (all) {
          final person = groupJadwal(
            all,
            isSiswa: isSiswa,
          ).where((p) => p.id == widget.personId).firstOrNull;
          if (person == null) {
            return SafeArea(
              child: Padding(
                padding: screenPadding,
                child: EmptyState(
                  icon: Icons.event_busy_rounded,
                  title: 'Kelas tidak ditemukan',
                  message: 'Belum ada sesi lunas bersama orang ini.',
                  action: FilledButton(
                    onPressed: () => context.pop(),
                    child: const Text('Kembali'),
                  ),
                ),
              ),
            );
          }

          final list = _history ? person.history : person.upcoming;
          final featured = !_history && list.isNotEmpty ? list.first : null;
          final rest = featured == null ? list : list.skip(1).toList();
          void open(BookingItem b) => context.push('/sesi/${b.id}');

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(jadwalProvider),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                PersonHero(
                  person: person,
                  isSiswa: isSiswa,
                  onChat: () => context.push(
                    '/chat/room/${person.id}',
                    extra: {'name': person.name, 'avatar': person.photoUrl},
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      StatTiles(person: person),
                      const SizedBox(height: AppSpacing.xl),
                      SegmentedTabs(
                        left: 'Jadwal',
                        right: 'Riwayat kelas',
                        rightSelected: _history,
                        onChanged: (v) => setState(() => _history = v),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (list.isEmpty)
                        EmptyState(
                          icon: _history
                              ? Icons.history_rounded
                              : Icons.event_busy_rounded,
                          title: _history
                              ? 'Belum ada riwayat kelas'
                              : 'Belum ada jadwal baru',
                          message: _history
                              ? 'Sesi yang sudah berjalan akan tampil di sini.'
                              : isSiswa
                              ? 'Beli paket lagi untuk menambah pertemuan.'
                              : 'Belum ada sesi mendatang dengan siswa ini.',
                          action: isSiswa && !_history
                              ? FilledButton.icon(
                                  onPressed: () =>
                                      context.push('/paket/beli/${person.id}'),
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Tambah pertemuan'),
                                )
                              : null,
                        )
                      else ...[
                        if (featured != null) ...[
                          _Label(text: 'Sesi berikutnya'),
                          const SizedBox(height: AppSpacing.sm),
                          NextSessionCard(booking: featured, isSiswa: isSiswa),
                          if (rest.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xl),
                            _Label(text: 'Setelahnya'),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                        ],
                        for (final b in rest) ...[
                          LessonTile(booking: b, onTap: () => open(b)),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}
