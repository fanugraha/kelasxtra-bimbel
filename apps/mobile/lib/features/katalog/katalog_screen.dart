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
import 'widgets/tutor_showcase_card.dart';
import 'katalog_filter_sheet.dart';
import 'katalog_providers.dart';
import 'katalog_repository.dart';

class KatalogScreen extends ConsumerStatefulWidget {
  const KatalogScreen({super.key});

  @override
  ConsumerState<KatalogScreen> createState() => _KatalogScreenState();
}

class _KatalogScreenState extends ConsumerState<KatalogScreen> {
  final _search = TextEditingController();
  var _query = '';

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

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(tutorListProvider),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 36),
            children: [
              sidePad(
                const ScreenHead(
                  eyebrow: 'Katalog',
                  title: 'Cari Tutor',
                  subtitle:
                      'Pilih mapel, jenjang, dan jadwal yang cocok. Semua tutor sudah diverifikasi.',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              sidePad(
                TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Cari nama atau mapel',
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
                        onTap: () =>
                            ref.read(katalogFilterProvider.notifier).setSubject(
                                  null,
                                ),
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
              const SizedBox(height: AppSpacing.lg),
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
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontSize: 10.5),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (final t in list) ...[
                          TutorListCard(
                            name: t.fullName,
                            rating: t.ratingAvg,
                            education: t.education,
                            subjectLine: t.subjectLine,
                            days: t.dayLabels,
                            photoUrl: t.photoUrl,
                            minPrice: t.minPrice,
                            onTap: () => context.push('/tutor/${t.id}'),
                          ),
                          const SizedBox(height: AppSpacing.sm),
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

  /// Chip "filter aktif" — satu chip yang bisa dilepas untuk tiap pilihan.
  List<Widget> _activeChips(KatalogFilter filter, List<SubjectOption> subjects) {
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
      for (final day in (filter.days.toList()
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

/// Tombol utama filter: menyebut jumlah filter aktif supaya siswa tahu ada
/// pilihan yang sedang berlaku walau hasilnya tak terlihat berubah.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = count > 0;
    return SizedBox(
      height: 44,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.tune_rounded, size: 18),
        label: Text(active ? 'Filter ($count)' : 'Filter'),
        style: FilledButton.styleFrom(
          backgroundColor: active
              ? scheme.primary.withValues(alpha: 0.14)
              : scheme.surfaceContainerHighest,
          foregroundColor: active ? scheme.primary : scheme.onSurface,
          side: BorderSide(
            color: active ? scheme.primary.withValues(alpha: 0.35) : scheme.outline,
          ),
          textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
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
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.swap_vert_rounded, size: 18),
        label: Text('Urutan: ${sort.label}'),
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
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
