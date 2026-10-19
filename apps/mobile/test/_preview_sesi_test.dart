import 'dart:io';

import 'package:bimbel_mobile/core/theme/app_theme.dart';
import 'package:bimbel_mobile/features/booking/booking_repository.dart';
import 'package:bimbel_mobile/features/booking/widgets/class_access_card.dart';
import 'package:bimbel_mobile/features/booking/widgets/session_hero.dart';
import 'package:bimbel_mobile/features/booking/widgets/session_note_card.dart';
import 'package:bimbel_mobile/features/booking/widgets/session_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BookingDetail _d({
  required DateTime at,
  String status = 'confirmed',
  String mode = 'online',
  String? url = 'https://zoom.us/j/123456789',
  SessionNote? note,
}) => BookingDetail(
  id: '1',
  studentId: 's',
  tutorId: 't',
  tutorName: 'Kak Rani',
  studentName: 'Alya',
  subjectName: 'Matematika',
  jenjang: 'SMA',
  durationMinutes: 90,
  mode: mode,
  scheduledAt: at,
  status: status,
  price: 0,
  meetingUrl: url,
  address: 'Jl. Kenanga No. 12, Bandung',
  note: note,
);

Widget _column(BookingDetail b, {bool notesFirst = false}) {
  final access = ClassAccessCard(booking: b, isTutor: false, onChat: () {});
  final notes = SessionNoteCard(
    note: b.note,
    emptyHint: 'Catatan dari tutor muncul setelah sesi berjalan.',
  );
  return SizedBox(
    width: 360,
    child: ListView(
      padding: EdgeInsets.zero,
      children: [
        SessionHero(booking: b, isTutor: false, onChat: () {}),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (notesFirst) notes else access,
              const SizedBox(height: 16),
              if (notesFirst) access else notes,
              const SizedBox(height: 18),
              SessionOptions(
                options: [
                  SessionOption(
                    icon: Icons.schedule_rounded,
                    label: 'Ajukan ganti hari',
                    subtitle: 'Tutor perlu menyetujui jadwal barunya',
                    onTap: () {},
                  ),
                  SessionOption(
                    icon: Icons.person_off_outlined,
                    label: 'Tutor tidak hadir',
                    danger: true,
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

void main() {
  testWidgets('preview detail sesi', (tester) async {
    tester.view.physicalSize = const Size(1080, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    const note = SessionNote(
      material: 'Limit fungsi aljabar & trigonometri',
      progress: 'Sudah paham substitusi, masih ragu di bentuk 0/0.',
      nextStep: 'Kerjakan latihan bab 3 nomor 1-10.',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _column(_d(at: now.add(const Duration(minutes: 5)))),
              _column(_d(at: now.add(const Duration(hours: 3)))),
              _column(
                _d(
                  at: now.subtract(const Duration(days: 1)),
                  status: 'completed',
                  note: note,
                ),
                notesFirst: true,
              ),
            ],
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/sesi_preview.png'),
    );
  }, skip: !Platform.isMacOS);
}
