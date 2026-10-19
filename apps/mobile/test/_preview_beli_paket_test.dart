import 'dart:io';

import 'package:bimbel_mobile/core/theme/app_theme.dart';
import 'package:bimbel_mobile/features/booking/booking_providers.dart';
import 'package:bimbel_mobile/features/katalog/katalog_repository.dart';
import 'package:bimbel_mobile/features/paket/beli_paket/beli_paket_controller.dart';
import 'package:bimbel_mobile/features/paket/beli_paket/steps/step_atur_kelas.dart';
import 'package:bimbel_mobile/features/paket/beli_paket/steps/step_pembayaran.dart';
import 'package:bimbel_mobile/features/paket/beli_paket/widgets/checkout_parts.dart';
import 'package:bimbel_mobile/features/paket/paket_providers.dart';
import 'package:bimbel_mobile/features/paket/paket_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _detail = TutorDetail(
  tutor: TutorCatalogItem(
    id: 't',
    fullName: 'Budi Santoso',
    education: 'S1 Pendidikan Matematika',
    ratingAvg: 4.67,
  ),
  subjects: [
    TutorSubjectItem(subjectId: 'm', subjectName: 'Matematika', jenjang: 'SMA'),
    TutorSubjectItem(subjectId: 'f', subjectName: 'Fisika', jenjang: 'SMA'),
  ],
  availability: [
    TutorAvailabilityItem(
      dayOfWeek: 1,
      startTime: '16:00',
      endTime: '19:00',
      mode: 'online',
    ),
    TutorAvailabilityItem(
      dayOfWeek: 4,
      startTime: '15:00',
      endTime: '17:00',
      mode: 'online',
    ),
    TutorAvailabilityItem(
      dayOfWeek: 6,
      startTime: '09:00',
      endTime: '12:00',
      mode: 'offline',
    ),
  ],
);

void main() {
  testWidgets('preview beli paket', (tester) async {
    tester.view.physicalSize = const Size(780, 2300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final c = BeliPaketController(
      tutorId: 't',
      repository: PaketRepository(),
      invalidateBusy: () {},
    );
    c.selectSubject(_detail.subjects.first);
    c.selectMode('online');
    c.selectSize(8);
    final opts = c.weeklyOptions(
      availability: _detail.availability,
      tutorBusy: const [],
      mine: const [],
    );
    c.selectWeekly(opts.first);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          packagePriceProvider.overrideWith(
            (ref, a) async => switch (a.totalSesi) {
              4 => 600000,
              8 => 1120000,
              _ => 1560000,
            },
          ),
          myCreditProvider.overrideWith((ref) async => 0),
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
                      const CheckoutStepper(current: 0),
                      const SizedBox(height: 18),
                      StepAturKelas(
                        controller: c,
                        detail: _detail,
                        busy: const <BusySlot>[],
                        mine: const [],
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 390,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const CheckoutStepper(current: 1),
                      const SizedBox(height: 18),
                      StepPembayaran(
                        controller: c,
                        detail: _detail,
                        amounts: (
                          price: 1120000,
                          discount: 0,
                          credits: 0,
                          pay: 1120000,
                        ),
                        onEdit: () {},
                        onApplyVoucher: () {},
                        onClearVoucher: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/beli_paket_preview.png'),
    );
  }, skip: !Platform.isMacOS);
}
