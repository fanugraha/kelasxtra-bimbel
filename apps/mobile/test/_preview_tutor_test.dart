import 'dart:io';

import 'package:bimbel_mobile/core/theme/app_theme.dart';
import 'package:bimbel_mobile/features/katalog/katalog_providers.dart';
import 'package:bimbel_mobile/features/katalog/katalog_repository.dart';
import 'package:bimbel_mobile/features/katalog/widgets/tutor_action_bar.dart';
import 'package:bimbel_mobile/features/katalog/widgets/tutor_detail_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('preview profil tutor', (tester) async {
    tester.view.physicalSize = const Size(390, 2500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const detail = TutorDetail(
      tutor: TutorCatalogItem(
        id: 't',
        fullName: 'Siti Rahayu',
        education: 'S1 Pendidikan Matematika, UPI',
        bio: 'Mengajar matematika SMA sejak 2019.',
        ratingAvg: 4.9,
      ),
      subjects: [
        TutorSubjectItem(
          subjectId: 'm',
          subjectName: 'Matematika',
          jenjang: 'SMP',
        ),
        TutorSubjectItem(
          subjectId: 'm',
          subjectName: 'Matematika',
          jenjang: 'SMA',
        ),
        TutorSubjectItem(subjectId: 'f', subjectName: 'Fisika', jenjang: 'SMA'),
      ],
      availability: [
        TutorAvailabilityItem(
          dayOfWeek: 1,
          startTime: '16:00',
          endTime: '18:00',
          mode: 'online',
        ),
        TutorAvailabilityItem(
          dayOfWeek: 1,
          startTime: '19:00',
          endTime: '21:00',
          mode: 'online',
        ),
        TutorAvailabilityItem(
          dayOfWeek: 3,
          startTime: '16:00',
          endTime: '18:00',
          mode: 'offline',
        ),
        TutorAvailabilityItem(
          dayOfWeek: 5,
          startTime: '15:00',
          endTime: '17:00',
          mode: 'online',
        ),
        TutorAvailabilityItem(
          dayOfWeek: 6,
          startTime: '09:00',
          endTime: '12:00',
          mode: 'online',
        ),
      ],
      minPackagePrice: 600000,
      minPackageSesi: 4,
    );

    final reviews = [
      TutorReview(
        id: '1',
        rating: 5,
        comment: 'Penjelasannya runtut, limit jadi gampang.',
        createdAt: DateTime(2026, 10, 12),
      ),
      TutorReview(
        id: '2',
        rating: 4,
        comment: 'Sabar dan jelas.',
        createdAt: DateTime(2026, 10, 5),
      ),
      TutorReview(id: '3', rating: 5, createdAt: DateTime(2026, 9, 28)),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tutorReviewsProvider('t').overrideWith((ref) async => reviews),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: SafeArea(child: TutorDetailContent(detail: detail)),
            bottomNavigationBar: TutorActionBar(detail: detail),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/tutor_preview.png'),
    );
  }, skip: !Platform.isMacOS);
}
