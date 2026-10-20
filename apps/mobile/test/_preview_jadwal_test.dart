import 'dart:io';
import 'package:bimbel_mobile/core/theme/app_theme.dart';
import 'package:bimbel_mobile/features/booking/booking_repository.dart';
import 'package:bimbel_mobile/features/jadwal/jadwal_grouping.dart';
import 'package:bimbel_mobile/features/jadwal/widgets/lesson_tile.dart';
import 'package:bimbel_mobile/features/jadwal/widgets/next_session_card.dart';
import 'package:bimbel_mobile/features/jadwal/widgets/person_card.dart';
import 'package:bimbel_mobile/features/jadwal/widgets/person_hero.dart';
import 'package:bimbel_mobile/features/jadwal/widgets/segmented_tabs.dart';
import 'package:bimbel_mobile/features/jadwal/widgets/stat_tiles.dart';
import 'package:bimbel_mobile/features/jadwal/widgets/up_next_card.dart';
import 'package:bimbel_mobile/features/jadwal/widgets/week_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

BookingItem _b({
  required String id,
  required String subject,
  required String tutor,
  required DateTime at,
  String status = 'confirmed',
  String mode = 'online',
  int duration = 90,
  String? tutorId,
}) => BookingItem(
  id: id,
  tutorId: tutorId ?? 't-$id',
  studentId: 's-1',
  tutorName: tutor,
  studentName: 'Alya',
  subjectName: subject,
  jenjang: 'SMA',
  durationMinutes: duration,
  mode: mode,
  scheduledAt: at,
  status: status,
  price: 150000,
);

const _fontPath = '/System/Library/Fonts/Supplemental/Arial.ttf';

void main() {
  testWidgets('preview jadwal', (tester) async {
    await tester.runAsync(() async {
      final loader = FontLoader('WorkSans')
        ..addFont(
          File(_fontPath).readAsBytes().then((b) => ByteData.view(b.buffer)),
        );
      await loader.load();
    });

    tester.view.physicalSize = const Size(720, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final now = DateTime(2026, 10, 20, 12);
    DateTime d(int days, int h) =>
        DateTime(now.year, now.month, now.day + days, h);
    final all = [
      _b(
        id: '1',
        subject: 'Matematika',
        tutor: 'Kak Rani',
        tutorId: 'rani',
        at: d(0, 16),
      ),
      _b(
        id: '2',
        subject: 'Matematika',
        tutor: 'Kak Rani',
        tutorId: 'rani',
        at: d(2, 16),
        status: 'rescheduled',
      ),
      _b(
        id: '3',
        subject: 'Matematika',
        tutor: 'Kak Rani',
        tutorId: 'rani',
        at: d(5, 16),
      ),
      _b(
        id: '4',
        subject: 'Matematika',
        tutor: 'Kak Rani',
        tutorId: 'rani',
        at: d(-3, 16),
        status: 'completed',
      ),
      _b(
        id: '5',
        subject: 'Fisika',
        tutor: 'Kak Budi',
        tutorId: 'budi',
        at: d(1, 10),
      ),
      _b(
        id: '6',
        subject: 'Kimia',
        tutor: 'Kak Dita',
        tutorId: 'dita',
        at: d(-6, 9),
        status: 'completed',
        duration: 120,
      ),
    ];
    final people = groupJadwal(all, isSiswa: true);
    final rani = people.first;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 360,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    UpNextCard(booking: rani.upcoming.first, isSiswa: true),
                    const SizedBox(height: 12),
                    WeekStrip(
                      upcoming: [for (final p in people) ...p.upcoming],
                    ),
                    const SizedBox(height: 18),
                    for (var i = 0; i < people.length; i++) ...[
                      PersonCard(
                        person: people[i],
                        isSiswa: true,
                        onTap: () {},
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
              SizedBox(
                width: 360,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    PersonHero(person: rani, isSiswa: true, onChat: () {}),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          StatTiles(person: rani),
                          const SizedBox(height: 18),
                          SegmentedTabs(
                            left: 'Jadwal',
                            right: 'Riwayat kelas',
                            rightSelected: false,
                            onChanged: (_) {},
                          ),
                          const SizedBox(height: 16),
                          NextSessionCard(
                            booking: rani.upcoming.first,
                            isSiswa: true,
                          ),
                          const SizedBox(height: 16),
                          for (final b in [
                            ...rani.upcoming.skip(1),
                            ...rani.history,
                          ]) ...[
                            LessonTile(booking: b, onTap: () {}),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/jadwal_preview.png'),
    );
  }, skip: !File(_fontPath).existsSync());
}
