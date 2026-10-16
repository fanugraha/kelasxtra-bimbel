import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'katalog_providers.dart';
import 'katalog_repository.dart';

class TutorDetailScreen extends ConsumerWidget {
  const TutorDetailScreen({super.key, required this.tutorId});

  final String tutorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(tutorDetailProvider(tutorId));

    return Scaffold(
      appBar: AppBar(title: const Text('Profil Tutor')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat profil.\n$e')),
        data: (d) {
          if (d == null) {
            return const Center(child: Text('Tutor tidak ditemukan.'));
          }
          return _Content(detail: d);
        },
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.detail});

  final TutorDetail detail;

  @override
  Widget build(BuildContext context) {
    final t = detail.tutor;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: CircleAvatar(
            radius: 44,
            backgroundImage: (t.photoUrl != null && t.photoUrl!.isNotEmpty)
                ? NetworkImage(t.photoUrl!)
                : null,
            child: (t.photoUrl == null || t.photoUrl!.isEmpty)
                ? Text(t.fullName.isEmpty ? '?' : t.fullName[0].toUpperCase(),
                    style: const TextStyle(fontSize: 32))
                : null,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(t.fullName, style: theme.textTheme.titleLarge),
        ),
        if (t.education != null && t.education!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Center(child: Text(t.education!, style: theme.textTheme.bodyMedium)),
        ],
        const SizedBox(height: 8),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, size: 18, color: Colors.amber),
              const SizedBox(width: 4),
              Text(t.ratingAvg.toStringAsFixed(1)),
            ],
          ),
        ),
        if (t.bio != null && t.bio!.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Tentang', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(t.bio!),
        ],
        const SizedBox(height: 20),
        Text('Mapel & Jenjang', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (detail.subjects.isEmpty)
          const Text('Belum ada data mapel.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in detail.subjects)
                Chip(label: Text('${s.subjectName} · ${s.jenjang}')),
            ],
          ),
        const SizedBox(height: 20),
        Text('Jadwal Ketersediaan', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (detail.availability.isEmpty)
          const Text('Belum ada jadwal.')
        else
          Column(
            children: [
              for (final a in detail.availability)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    a.mode == 'online' ? Icons.videocam : Icons.place,
                  ),
                  title: Text(a.dayName),
                  subtitle: Text(a.timeRange),
                  trailing: Text(a.mode == 'online' ? 'Online' : 'Offline'),
                ),
            ],
          ),
        const SizedBox(height: 24),
        const Text(
          'Booking & pembayaran menyusul.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
