import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: filter.jenjang ?? '',
                    decoration: const InputDecoration(labelText: 'Jenjang'),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('Semua')),
                      DropdownMenuItem(value: 'SD', child: Text('SD')),
                      DropdownMenuItem(value: 'SMP', child: Text('SMP')),
                      DropdownMenuItem(value: 'SMA', child: Text('SMA')),
                    ],
                    onChanged: (v) => ref
                        .read(katalogFilterProvider.notifier)
                        .setJenjang((v == null || v.isEmpty) ? null : v),
                  ),
                ),
                const SizedBox(width: 12),
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
            child: tutors.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Gagal memuat katalog.\n$e')),
              data: (list) => list.isEmpty
                  ? const Center(
                      child: Text('Belum ada tutor untuk filter ini.'))
                  : RefreshIndicator(
                      onRefresh: () async => ref.invalidate(tutorListProvider),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        itemBuilder: (c, i) => _TutorCard(tutor: list[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorCard extends StatelessWidget {
  const _TutorCard({required this.tutor});

  final TutorCatalogItem tutor;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 26,
          backgroundImage:
              (tutor.photoUrl != null && tutor.photoUrl!.isNotEmpty)
                  ? NetworkImage(tutor.photoUrl!)
                  : null,
          child: (tutor.photoUrl == null || tutor.photoUrl!.isEmpty)
              ? Text(tutor.fullName.isEmpty ? '?' : tutor.fullName[0].toUpperCase())
              : null,
        ),
        title: Text(tutor.fullName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tutor.education != null && tutor.education!.isNotEmpty)
              Text(tutor.education!, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.star, size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                Text(tutor.ratingAvg.toStringAsFixed(1)),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/tutor/${tutor.id}'),
      ),
    );
  }
}
