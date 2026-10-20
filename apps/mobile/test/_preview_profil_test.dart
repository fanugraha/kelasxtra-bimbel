import 'dart:io';

import 'package:bimbel_mobile/core/app_flavor.dart';
import 'package:bimbel_mobile/core/providers.dart';
import 'package:bimbel_mobile/core/theme/app_theme.dart';
import 'package:bimbel_mobile/features/auth/auth_providers.dart';
import 'package:bimbel_mobile/features/auth/auth_repository.dart';
import 'package:bimbel_mobile/features/auth/edit_biodata_screen.dart';
import 'package:bimbel_mobile/features/auth/profil_screen.dart';
import 'package:bimbel_mobile/features/auth/riwayat_poin_screen.dart';
import 'package:bimbel_mobile/features/auth/ubah_password_screen.dart';
import 'package:bimbel_mobile/features/bank_soal/bank_soal_providers.dart';
import 'package:bimbel_mobile/features/bank_soal/bank_soal_repository.dart';
import 'package:bimbel_mobile/features/booking/booking_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final MyProfile _p = (
  role: 'student',
  fullName: 'Rani Demo',
  email: 'rani@contoh.id',
  phone: '081234567890',
  jenjang: 'SMA',
  school: 'SMAN 3 Bandung',
  emergencyContactName: 'Ibu Sari',
  emergencyContactPhone: null,
  avatarUrl: null,
  birthDate: DateTime(2009, 5, 17),
);

void main() {
  test('kekuatan password', () {
    expect(passwordStrength('abc'), 0);
    expect(passwordStrength('abcdefgh'), 1);
    expect(passwordStrength('abcd1234'), 2);
    expect(passwordStrength('abcd1234!x'), 3);
  });

  test('validasi nomor HP', () {
    expect(validatePhone('0812 3456 7890'), isNull);
    expect(validatePhone('+6281234567890'), isNull);
    expect(validatePhone('12345'), isNotNull);
    expect(validatePhone(''), isNull);
    expect(validatePhone('', required: true), 'Wajib diisi');
  });

  testWidgets('preview profil', (tester) async {
    tester.view.physicalSize = const Size(1170, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appFlavorProvider.overrideWithValue(AppFlavor.siswa),
          myProfileProvider.overrideWith((ref) async => _p),
          myCreditProvider.overrideWith((ref) async => 25000),
          mySubscriptionProvider.overrideWith(
            (ref) async => SubscriptionInfo(
              status: 'active',
              currentPeriodEnd: DateTime(2026, 11, 18),
            ),
          ),
          creditHistoryProvider.overrideWith(
            (ref) async => [
              CreditEntry(
                amount: -15000,
                reason: 'checkout',
                createdAt: DateTime(2026, 10, 18, 14, 5),
              ),
              CreditEntry(
                amount: 40000,
                reason: 'tutor_no_show',
                createdAt: DateTime(2026, 10, 12, 16, 30),
              ),
            ],
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Row(
            children: [
              SizedBox(width: 390, child: ProfilScreen()),
              SizedBox(width: 390, child: EditBiodataScreen()),
              SizedBox(width: 390, child: RiwayatPoinScreen()),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Row).first,
      matchesGoldenFile('goldens/profil_preview.png'),
    );
  }, skip: !Platform.isMacOS);
}
