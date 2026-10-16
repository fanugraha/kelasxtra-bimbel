import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/async_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/tutor_card.dart';
import 'katalog_providers.dart';
import 'katalog_repository.dart';

class KatalogScreen extends ConsumerWidget {
  const KatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(katalogFilterProvider);
    final subjects = ref.watch(subjectsProvider);
    final tutors = ref.watch(tutorListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cari Tutor')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: filter.jenjang ?? '',
                    decoration: const InputDecoration(labelText: 'Jenjang'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Semua')),
                      for (final j in AppConstants.jenjang)
                        DropdownMenuItem(value: j, child: Text(j)),
                    ],
                    onChanged: (v) => ref
                        .read(katalogFilterProvider.notifier)
                        .setJenjang((v == null || v.isEmpty) ? null : v),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: filter.subjectId ?? '',
                    decoration: const InputDecoration(labelText: 'Mapel'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Semua')),
                      ...subjects.maybeWhen(
                        data: (list) => [
                          for (final s in list)
                            DropdownMenuItem(value: s.id, child: Text(s.name)),
                        ],
                        orElse: () => const <DropdownMenuItem<String>>[],
                      ),
                    ],
                    onChanged: (v) => ref
                        .read(katalogFilterProvider.notifier)
                        .setSubject((v == null || v.isEmpty) ? null : v),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncView<List<TutorCatalogItem>>(
              value: tutors,
              errorTitle: 'Gagal memuat katalog',
              onRetry: () => ref.invalidate(tutorListProvider),
              loading: const _LoadingList(),
              builder: (list) => list.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Belum ada tutor',
                      message: 'Coba ubah filter jenjang atau mapel.',
                    )
                  : RefreshIndicator(
                      onRefresh: () async => ref.invalidate(tutorListProvider),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.sm,
                          AppSpacing.lg,
                          AppSpacing.xxl,
                        ),
                        itemCount: list.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (c, i) {
                          final t = list[i];
                          return TutorCard(
                            name: t.fullName,
                            rating: t.ratingAvg,
                            education: t.education,
                            photoUrl: t.photoUrl,
                            onTap: () => context.push('/tutor/${t.id}'),
                          );
                        },
                      ),
                    ),
            ),
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
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (c, i) => const TutorCard(
          name: 'Nama Tutor Contoh',
          rating: 4.8,
          education: 'Universitas Contoh',
        ),
      ),
    );
  }
}
