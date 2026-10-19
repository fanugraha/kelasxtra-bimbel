import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import 'katalog_providers.dart';
import 'katalog_repository.dart';
import 'widgets/tutor_action_bar.dart';
import 'widgets/tutor_detail_content.dart';

/// Profil tutor: identitas + harga, lalu Tentang, mapel, dan jadwal mingguan.
///
/// Hierarki teks: judul halaman (25, nama tutor) → judul bagian (16.5) →
/// isi (13.5) → catatan (11.5). Jarak antar bagian 24, di dalam bagian 8–12.
class TutorDetailScreen extends ConsumerWidget {
  const TutorDetailScreen({super.key, required this.tutorId});

  final String tutorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(tutorDetailProvider(tutorId));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncView<TutorDetail?>(
          value: detail,
          errorTitle: 'Gagal memuat profil',
          onRetry: () => ref.invalidate(tutorDetailProvider(tutorId)),
          builder: (d) => d == null
              ? const EmptyState(
                  icon: Icons.person_off_rounded,
                  title: 'Tutor tidak ditemukan',
                )
              : TutorDetailContent(detail: d),
        ),
      ),
      bottomNavigationBar: detail.maybeWhen(
        data: (d) => d == null ? null : TutorActionBar(detail: d),
        orElse: () => null,
      ),
    );
  }
}
