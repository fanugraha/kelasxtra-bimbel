import 'package:bimbel_mobile/core/app_flavor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('label flavor sesuai', () {
    expect(AppFlavor.siswa.label, 'Siswa');
    expect(AppFlavor.tutor.label, 'Tutor');
  });
}
