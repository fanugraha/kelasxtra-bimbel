import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../katalog_repository.dart';
import 'tutor_profile_header.dart';
import 'tutor_profile_sections.dart';

/// Isi halaman profil tutor: foto besar + ringkasan, lalu semua informasi
/// dijabarkan berurutan dalam kartu-kartu (tanpa tab), supaya siswa cukup
/// menggulir dan tidak ada yang terlewat. Urutan mengikuti pertanyaan siswa:
/// siapa tutornya → mengajar apa → kapan bisa → kata siswa lain.
/// Aksi utama (Beli Paket) ada di bar bawah.
class TutorDetailContent extends StatelessWidget {
  const TutorDetailContent({super.key, required this.detail});

  final TutorDetail detail;

  @override
  Widget build(BuildContext context) {
    final d = detail;
    const gap = SizedBox(height: AppSpacing.md + 2);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg + 4,
        AppSpacing.md,
        AppSpacing.lg + 4,
        AppSpacing.xxl,
      ),
      children: [
        TutorProfileHeader(
          detail: d,
          onChat: () => context.push(
            '/chat/room/${d.tutor.id}',
            extra: {'name': d.tutor.fullName, 'avatar': d.tutor.photoUrl},
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AboutSection(tutor: d.tutor),
        gap,
        SubjectsSection(subjects: d.subjects),
        gap,
        ScheduleSection(slots: d.availability),
        gap,
        ReviewsSection(tutor: d.tutor),
      ],
    );
  }
}
