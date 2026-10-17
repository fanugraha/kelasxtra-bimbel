import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/screen_head.dart';
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

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(katalogFilterProvider);
    final subjects = ref.watch(subjectsProvider);
    final tutors = ref.watch(tutorListProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(tutorListProvider),
          child: ListView(
            padding: screenPadding,
            children: [
              const ScreenHead(
                eyebrow: 'Katalog',
                title: 'Cari Tutor',
                subtitle: 'Pilih mapel atau mode belajar. Semua tutor sudah diverifikasi.',
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 12),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _Chip(
                      label: 'Semua',
                      selected: filter.subjectId == null && filter.mode == null,
                      onTap: () {
                        ref.read(katalogFilterProvider.notifier).setSubject(null);
                        ref.read(katalogFilterProvider.notifier).setMode(null);
                      },
                    ),
                    ...subjects.value?.map(
                          (s) => _Chip(
                            label: s.name,
                            selected: filter.subjectId == s.id,
                            onTap: () => ref
                                .read(katalogFilterProvider.notifier)
                                .setSubject(filter.subjectId == s.id ? null : s.id),
                          ),
                        ) ??
                        const [],
                    _Chip(
                      label: 'Online',
                      selected: filter.mode == 'online',
                      onTap: () => ref
                          .read(katalogFilterProvider.notifier)
                          .setMode(filter.mode == 'online' ? null : 'online'),
                    ),
                    _Chip(
                      label: 'Offline',
                      selected: filter.mode == 'offline',
                      onTap: () => ref
                          .read(katalogFilterProvider.notifier)
                          .setMode(filter.mode == 'offline' ? null : 'offline'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AsyncView<List<TutorCatalogItem>>(
                value: tutors,
                errorTitle: 'Gagal memuat katalog',
                onRetry: () => ref.invalidate(tutorListProvider),
                loading: const _LoadingList(),
                builder: (all) {
                  final list = _query.isEmpty
                      ? all
                      : all
                          .where((t) =>
                              t.fullName.toLowerCase().contains(_query) ||
                              (t.education ?? '')
                                  .toLowerCase()
                                  .contains(_query))
                          .toList();
                  if (list.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'Tidak ada tutor yang cocok',
                        message:
                            'Coba kata kunci lain, atau kembalikan filter ke semua tutor.',
                      ),
                    );
                  }
                  return Column(
                    children: [
                      Row(
                        children: [
                          Text('${list.length} tutor ditemukan',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontSize: 10.5)),
                          const Spacer(),
                          Text('Rating tertinggi',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontSize: 10.5)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final t in list) ...[
                        _TutorRow(tutor: t),
                        const SizedBox(height: 8),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.11)
                : scheme.surface,
            border: Border.all(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.35)
                  : scheme.outline,
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _TutorRow extends StatelessWidget {
  const _TutorRow({required this.tutor});
  final TutorCatalogItem tutor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = tutor.fullName.isEmpty ? '?' : tutor.fullName[0].toUpperCase();

    return AppCard(
      onTap: () => context.push('/tutor/${tutor.id}'),
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.11),
            child: Text(initial,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tutor.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  tutor.education ?? 'Tutor terverifikasi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 14, color: AppColors.star),
                    const SizedBox(width: 3),
                    Text(tutor.ratingAvg.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 10.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Lihat',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary)),
              const SizedBox(height: 2),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ],
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
              padding: EdgeInsets.all(13),
              child: Row(
                children: [
                  CircleAvatar(radius: 24),
                  SizedBox(width: 11),
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
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
