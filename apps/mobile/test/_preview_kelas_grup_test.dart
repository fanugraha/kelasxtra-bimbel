import 'dart:io';

import 'package:bimbel_mobile/core/theme/app_theme.dart';
import 'package:bimbel_mobile/features/kelas_grup/kelas_grup_detail_screen.dart';
import 'package:bimbel_mobile/features/kelas_grup/kelas_grup_providers.dart';
import 'package:bimbel_mobile/features/kelas_grup/kelas_grup_repository.dart';
import 'package:bimbel_mobile/features/kelas_grup/widgets/group_class_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.now();

GroupClassItem _cls({int paid = 2, int held = 1}) => GroupClassItem(
  id: 'g',
  jenjang: 'SMA',
  mode: 'online',
  durationMinutes: 90,
  totalSesi: 4,
  discountPercent: 5,
  pricePerSession: 75000,
  priceTotal: 285000,
  minSeats: 3,
  maxSeats: 5,
  seatsTaken: paid + held + 1, // + tahanan milik siswa ini
  seatsPaid: paid,
  seatsHeld: held,
  status: 'open',
  minConfirmDeadline: DateTime(2026, 10, 26, 20),
  tutorId: 't',
  tutorName: 'Budi Santoso',
  tutorEducation: 'S1 Pendidikan Matematika',
  tutorRating: 4.67,
  tutorBio: 'Senang membuat limit dan turunan terasa masuk akal.',
  subjectName: 'Matematika',
  firstSession: DateTime(2026, 10, 27, 16),
  lastSession: DateTime(2026, 11, 17, 16),
);

void main() {
  test('terisi = lunas saja; tertahanSemua bila sisa kursi ditahan', () {
    final c = _cls(paid: 3, held: 2).copyWithTaken(5);
    expect(c.terisi, 3);
    expect(c.penuh, isTrue);
    expect(c.tertahanSemua, isTrue);
  });

  testWidgets('preview belajar bareng', (tester) async {
    tester.view.physicalSize = const Size(780, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupClassProvider('g').overrideWith((ref) async => _cls()),
          myGroupSeatProvider('g').overrideWith(
            (ref) async => GroupSeatItem(
              id: 's',
              groupClassId: 'g',
              pricePaid: 285000,
              status: 'pending_payment',
              lockExpiresAt: _now.add(const Duration(minutes: 3, seconds: 30)),
            ),
          ),
          groupSessionsProvider('g').overrideWith(
            (ref) async => [
              for (var i = 0; i < 4; i++)
                GroupSessionItem(
                  seq: i + 1,
                  scheduledAt: DateTime(2026, 10, 27 + i * 7, 16),
                ),
            ],
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 390,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      GroupClassCard(item: _cls(paid: 1, held: 0)),
                      const SizedBox(height: 10),
                      GroupClassCard(item: _cls(paid: 4, held: 0)),
                    ],
                  ),
                ),
                const SizedBox(
                  width: 390,
                  child: KelasGrupDetailScreen(classId: 'g'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('goldens/kelas_grup_preview.png'),
    );
    // Hentikan timer layar sebelum tes selesai.
    await tester.pumpWidget(const SizedBox());
  }, skip: !Platform.isMacOS);
}

extension on GroupClassItem {
  GroupClassItem copyWithTaken(int taken) => GroupClassItem(
    id: id,
    jenjang: jenjang,
    mode: mode,
    durationMinutes: durationMinutes,
    totalSesi: totalSesi,
    discountPercent: discountPercent,
    pricePerSession: pricePerSession,
    priceTotal: priceTotal,
    minSeats: minSeats,
    maxSeats: maxSeats,
    seatsTaken: taken,
    seatsPaid: seatsPaid,
    seatsHeld: seatsHeld,
    status: status,
    minConfirmDeadline: minConfirmDeadline,
  );
}
