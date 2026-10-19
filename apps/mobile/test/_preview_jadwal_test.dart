import 'dart:io';
import 'package:bimbel_mobile/core/theme/app_theme.dart';
import 'package:bimbel_mobile/features/booking/booking_repository.dart';
import 'package:bimbel_mobile/features/jadwal/widgets/next_session_card.dart';
import 'package:bimbel_mobile/features/jadwal/widgets/session_tile.dart';
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
}) => BookingItem(
  id: id,
  tutorId: 't-$id',
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

    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    final next = _b(
      id: '1',
      subject: 'Matematika',
      tutor: 'Kak Rani',
      at: DateTime(now.year, now.month, now.day, 16),
    );
    final rows = [
      _b(
        id: '2',
        subject: 'Fisika',
        tutor: 'Kak Budi',
        at: DateTime(now.year, now.month, now.day + 1, 10),
        status: 'rescheduled',
      ),
      _b(
        id: '3',
        subject: 'Bahasa Inggris',
        tutor: 'Kak Sinta',
        at: DateTime(now.year, now.month, now.day + 1, 19),
        mode: 'offline',
        duration: 60,
      ),
      _b(
        id: '4',
        subject: 'Kimia',
        tutor: 'Kak Dita',
        at: DateTime(now.year, now.month, now.day + 3, 9),
        duration: 120,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Sesi berikutnya'),
                const SizedBox(height: 8),
                NextSessionCard(booking: next, isSiswa: true),
                const SizedBox(height: 24),
                for (var i = 0; i < rows.length; i++)
                  SessionTile(
                    booking: rows[i],
                    isSiswa: true,
                    isFirst: i == 0,
                    isLast: i == rows.length - 1,
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(ListView),
      matchesGoldenFile('goldens/jadwal_preview.png'),
    );
  }, skip: !File(_fontPath).existsSync());
}
