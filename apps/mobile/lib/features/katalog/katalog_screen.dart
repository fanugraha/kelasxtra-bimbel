import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../core/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/screen_head.dart';
import '../../core/widgets/selectable_chip.dart';
import '../kelas_grup/kelas_grup_providers.dart';
import '../kelas_grup/kelas_grup_repository.dart';
import '../kelas_grup/widgets/group_class_card.dart';
import 'widgets/tutor_showcase_card.dart';
import 'katalog_filter_sheet.dart';
import 'katalog_providers.dart';
import 'katalog_repository.dart';

class KatalogScreen extends ConsumerStatefulWidget {
  const KatalogScreen({super.key});

  @override
  ConsumerState<KatalogScreen> createState() => _KatalogScreenState();
}

enum _CariMode { privat, grup }

class _KatalogScreenState extends ConsumerState<KatalogScreen> {
  final _search = TextEditingController();
  var _query = '';
  var _mode = _CariMode.privat;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearAll() {
    ref.read(katalogFilterProvider.notifier).reset();
    _search.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filter = ref.watch(katalogFilterProvider);
    final subjects = ref.watch(subjectsProvider).value ?? const [];
    final tutors = ref.watch(tutorListProvider);
    final groupClasses = ref.watch(groupClassesProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(tutorListProvider);
            ref.invalidate(groupClassesProvider);
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 36),
            children: [
              sidePad(
                ScreenHead(
                  title: 'Bimbel',
                  subtitle: _mode == _CariMode.privat
                      ? 'Pilih tutor privat sesuai mapel, jenjang, dan jadwal.'
                      : 'Belajar bareng 3–5 siswa dengan jadwal tetap dan harga lebih ringan.',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              sidePad(
                _ModeSwitch(
                  mode: _mode,
                  onChanged: (m) => setState(() => _mode = m),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              sidePad(
                TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: _mode == _CariMode.privat
                        ? 'Cari nama atau mapel'
                        : 'Cari mapel atau tutor',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                  ),
                ),
              ),
              if (_mode == _CariMode.privat) ...[
                const SizedBox(height: AppSpacing.md),
                sidePad(
                  Row(
                    children: [
                      Expanded(
                        child: _FilterButton(
                          count: filter.activeCount,
                          onTap: () => showKatalogFilterSheet(context),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _SortButton(
                        sort: filter.sort,
                        onTap: () => showKatalogSortSheet(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: screenSide,
                    children: [
                      Center(
                        child: SelectableChip(
                          label: 'Semua mapel',
                          selected: filter.subjectId == null,
                          onTap: () => ref
                              .read(katalogFilterProvider.notifier)
                              .setSubject(null),
                        ),
                      ),
                      for (final s in subjects)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(left: AppSpacing.sm),
                            child: SelectableChip(
                              label: s.name,
                              selected: filter.subjectId == s.id,
                              onTap: () => ref
                                  .read(katalogFilterProvider.notifier)
                                  .setSubject(
                                    filter.subjectId == s.id ? null : s.id,
                                  ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (filter.isFiltered) ...[
                  const SizedBox(height: AppSpacing.md),
                  sidePad(
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ..._activeChips(filter, subjects),
                        SelectableChip(label: 'Hapus semua', onTap: _clearAll),
                      ],
                    ),
                  ),
                ],
              ],
              const SizedBox(height: AppSpacing.lg),
              if (_mode == _CariMode.privat)
                sidePad(
                  AsyncView<List<TutorCatalogItem>>(
                    value: tutors,
                    errorTitle: 'Gagal memuat katalog',
                    onRetry: () => ref.invalidate(tutorListProvider),
                    loading: const _LoadingList(),
                    builder: (all) {
                      final list = _query.isEmpty
                          ? all
                          : all.where((t) => _matches(t, _query)).toList();
                      if (list.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xxl),
                          child: EmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'Tidak ada tutor yang cocok',
                            message: filter.isFiltered || _query.isNotEmpty
                                ? 'Coba hapus sebagian filter, atau lihat lagi semua tutor.'
                                : 'Katalog tutor belum tersedia saat ini.',
                            action: filter.isFiltered || _query.isNotEmpty
                                ? OutlinedButton.icon(
                                    onPressed: _clearAll,
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('Hapus semua filter'),
                                  )
                                : null,
                          ),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${list.length} tutor ditemukan',
                            style: theme.textTheme.labelSmall,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              const gap = AppSpacing.md;
                              final columns = constraints.maxWidth >= 560
                                  ? 3
                                  : 2;
                              final cardWidth =
                                  (constraints.maxWidth - gap * (columns - 1)) /
                                  columns;
                              final textScale =
                                  MediaQuery.textScalerOf(context).scale(16) /
                                  16;
                              final cardHeight =
                                  274 + (textScale - 1).clamp(0.0, 1.2) * 130;
                              return Wrap(
                                spacing: gap,
                                runSpacing: gap,
                                children: [
                                  for (final t in list)
                                    SizedBox(
                                      width: cardWidth,
                                      height: cardHeight,
                                      child: TutorListCard(
                                        name: t.fullName,
                                        rating: t.ratingAvg,
                                        education: t.education,
                                        subjectLine: t.subjectLine,
                                        days: t.dayLabels,
                                        photoUrl: t.photoUrl,
                                        minPrice: t.minPrice,
                                        onTap: () =>
                                            context.push('/tutor/${t.id}'),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                )
              else
                sidePad(
                  AsyncView<List<GroupClassItem>>(
                    value: groupClasses,
                    errorTitle: 'Gagal memuat kelas grup',
                    onRetry: () => ref.invalidate(groupClassesProvider),
                    builder: (all) {
                      final list = _query.isEmpty
                          ? all
                          : all.where((g) => _matchesGroup(g, _query)).toList();
                      if (list.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xxl),
                          child: EmptyState(
                            icon: Icons.groups_rounded,
                            title: 'Belum ada kelas grup',
                            message: _query.isNotEmpty
                                ? 'Coba kata kunci lain.'
                                : 'Kelas grup akan muncul di sini saat admin membukanya.',
                            action: _query.isNotEmpty
                                ? OutlinedButton.icon(
                                    onPressed: () {
                                      _search.clear();
                                      setState(() => _query = '');
                                    },
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('Hapus pencarian'),
                                  )
                                : null,
                          ),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${list.length} kelas grup ditemukan',
                            style: theme.textTheme.labelSmall,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          for (final item in list) ...[
                            GroupClassCard(item: item),
                            const SizedBox(height: 9),
                          ],
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool _matches(TutorCatalogItem t, String query) =>
      t.fullName.toLowerCase().contains(query) ||
      (t.education ?? '').toLowerCase().contains(query) ||
      (t.subjects ?? '').toLowerCase().contains(query);

  bool _matchesGroup(GroupClassItem g, String query) =>
      (g.subjectName ?? '').toLowerCase().contains(query) ||
      (g.tutorName ?? '').toLowerCase().contains(query) ||
      g.jenjang.toLowerCase().contains(query);

  /// Chip "filter aktif" — satu chip yang bisa dilepas untuk tiap pilihan.
  List<Widget> _activeChips(
    KatalogFilter filter,
    List<SubjectOption> subjects,
  ) {
    final notifier = ref.read(katalogFilterProvider.notifier);
    String? subjectName;
    for (final s in subjects) {
      if (s.id == filter.subjectId) {
        subjectName = s.name;
        break;
      }
    }

    return [
      if (filter.subjectId != null)
        SelectableChip(
          label: subjectName ?? 'Mapel',
          onRemove: () => notifier.setSubject(null),
        ),
      if (filter.jenjang != null)
        SelectableChip(
          label: filter.jenjang!,
          onRemove: () => notifier.setJenjang(null),
        ),
      if (filter.mode != null)
        SelectableChip(
          label: filter.mode == 'online' ? 'Online' : 'Offline',
          onRemove: () => notifier.setMode(null),
        ),
      for (final day
          in (filter.days.toList()
            ..sort((a, b) => (a == 0 ? 7 : a).compareTo(b == 0 ? 7 : b))))
        SelectableChip(
          label: AppFormat.shortDayName(day),
          onRemove: () => notifier.toggleDay(day),
        ),
      if (filter.minRating != null)
        SelectableChip(
          label: 'Rating ${filter.minRating!.toStringAsFixed(1)}+',
          onRemove: () => notifier.setMinRating(null),
        ),
    ];
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.mode, required this.onChanged});

  final _CariMode mode;
  final ValueChanged<_CariMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: _tab(
              context,
              _CariMode.privat,
              'Privat',
              Icons.person_outline_rounded,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _tab(context, _CariMode.grup, 'Grup', Icons.groups_outlined),
          ),
        ],
      ),
    );
  }

  Widget _tab(
    BuildContext context,
    _CariMode value,
    String label,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = mode == value;
    return Material(
      color: selected ? scheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tombol utama filter: menyebut jumlah filter aktif supaya siswa tahu ada
/// pilihan yang sedang berlaku walau hasilnya tak terlihat berubah.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final active = count > 0;
    return SizedBox(
      height: 48,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.tune_rounded, size: 18),
        label: Text(active ? 'Filter ($count)' : 'Filter'),
        style: FilledButton.styleFrom(
          backgroundColor: active ? scheme.primary : scheme.surface,
          foregroundColor: active ? scheme.onPrimary : scheme.onSurface,
          side: BorderSide(color: active ? scheme.primary : scheme.outline),
          textStyle: theme.textTheme.labelMedium,
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.sort, required this.onTap});

  final KatalogSort sort;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.swap_vert_rounded, size: 18),
        label: Text('Urutan: ${sort.label}'),
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          backgroundColor: scheme.surface,
          side: BorderSide(color: scheme.outline),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          textStyle: theme.textTheme.labelMedium,
        ),
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      child: Column(
        children: [
          for (var i = 0; i < 4; i++) ...[
            const AppCard(
              padding: EdgeInsets.all(AppSpacing.md + 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(radius: 22),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Nama Tutor Contoh'),
                            SizedBox(height: 4),
                            Text('Universitas Contoh'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.md),
                  Text('Matematika · SMP, SMA'),
                  SizedBox(height: AppSpacing.md),
                  Text('Mulai Rp75000'),
                  SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}
