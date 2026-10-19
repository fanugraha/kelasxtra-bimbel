import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/selectable_chip.dart';
import 'katalog_providers.dart';
import 'katalog_repository.dart';

/// Urutan hari yang enak dibaca (Senin…Sabtu, Minggu terakhir).
const _dayOptions = [1, 2, 3, 4, 5, 6, 0];

const _jenjangOptions = ['SD', 'SMP', 'SMA'];

const _ratingOptions = [4.5, 4.8];

/// Lembar bawah filter: semua pilihan yang tidak muat di layar hasil.
/// Filter langsung berlaku (tanpa tombol "Terapkan"), lalu ditutup dengan
/// tombol yang menyebut jumlah hasil.
Future<void> showKatalogFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _KatalogFilterSheet(),
  );
}

/// Lembar bawah "Urutkan" — dipisah dari filter supaya mengubah urutan tidak
/// perlu membuka seluruh lembar filter.
Future<void> showKatalogSortSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _SortSheet(),
  );
}

class _KatalogFilterSheet extends ConsumerWidget {
  const _KatalogFilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final filter = ref.watch(katalogFilterProvider);
    final notifier = ref.read(katalogFilterProvider.notifier);
    final subjects = ref.watch(subjectsProvider).value ?? const [];
    final count = ref.watch(tutorListProvider).value?.length;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 8, bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text('Filter', style: theme.textTheme.titleMedium),
                ),
                TextButton(
                  onPressed: filter.isFiltered ? notifier.reset : null,
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Group(
                    title: 'Mapel',
                    children: [
                      SelectableChip(
                        label: 'Semua mapel',
                        selected: filter.subjectId == null,
                        onTap: () => notifier.setSubject(null),
                      ),
                      for (final s in subjects)
                        SelectableChip(
                          label: s.name,
                          selected: filter.subjectId == s.id,
                          onTap: () => notifier.setSubject(
                            filter.subjectId == s.id ? null : s.id,
                          ),
                        ),
                    ],
                  ),
                  _Group(
                    title: 'Jenjang',
                    children: [
                      SelectableChip(
                        label: 'Semua',
                        selected: filter.jenjang == null,
                        onTap: () => notifier.setJenjang(null),
                      ),
                      for (final j in _jenjangOptions)
                        SelectableChip(
                          label: j,
                          selected: filter.jenjang == j,
                          onTap: () => notifier.setJenjang(
                            filter.jenjang == j ? null : j,
                          ),
                        ),
                    ],
                  ),
                  _Group(
                    title: 'Mode belajar',
                    children: [
                      SelectableChip(
                        label: 'Semua',
                        selected: filter.mode == null,
                        onTap: () => notifier.setMode(null),
                      ),
                      SelectableChip(
                        label: 'Online',
                        selected: filter.mode == 'online',
                        onTap: () => notifier.setMode(
                          filter.mode == 'online' ? null : 'online',
                        ),
                      ),
                      SelectableChip(
                        label: 'Offline',
                        selected: filter.mode == 'offline',
                        onTap: () => notifier.setMode(
                          filter.mode == 'offline' ? null : 'offline',
                        ),
                      ),
                    ],
                  ),
                  _Group(
                    title: 'Hari tersedia',
                    subtitle: 'Boleh pilih lebih dari satu hari',
                    children: [
                      for (final d in _dayOptions)
                        SelectableChip(
                          label: AppFormat.shortDayName(d),
                          selected: filter.days.contains(d),
                          onTap: () => notifier.toggleDay(d),
                        ),
                    ],
                  ),
                  _Group(
                    title: 'Rating minimum',
                    children: [
                      SelectableChip(
                        label: 'Semua',
                        selected: filter.minRating == null,
                        onTap: () => notifier.setMinRating(null),
                      ),
                      for (final r in _ratingOptions)
                        SelectableChip(
                          label: '${r.toStringAsFixed(1)}+',
                          selected: filter.minRating == r,
                          onTap: () => notifier.setMinRating(
                            filter.minRating == r ? null : r,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: theme.colorScheme.outline)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      count == null || count == 0
                          ? 'Tampilkan hasil'
                          : 'Tampilkan $count tutor',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortSheet extends ConsumerWidget {
  const _SortSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final current = ref.watch(katalogFilterProvider).sort;
    final notifier = ref.read(katalogFilterProvider.notifier);

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Urutkan', style: theme.textTheme.titleMedium),
          ),
          for (final sort in KatalogSort.values)
            ListTile(
              onTap: () {
                notifier.setSort(sort);
                Navigator.of(context).pop();
              },
              title: Text(
                sort.label,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: sort == current
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                sort.description,
                style: theme.textTheme.bodySmall,
              ),
              trailing: sort == current
                  ? Icon(
                      Icons.check_circle_rounded,
                      color: theme.colorScheme.primary,
                    )
                  : null,
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, this.subtitle, required this.children});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: AppSpacing.sm + 2),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: children,
          ),
        ],
      ),
    );
  }
}
