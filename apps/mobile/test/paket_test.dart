import 'package:bimbel_mobile/features/paket/paket_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('paketTotal: diskon 0% (4) / 5% (8) / 10% (12)', () {
    expect(paketTotal(pricePerSession: 85000, totalSesi: 4), 340000);
    expect(paketTotal(pricePerSession: 85000, totalSesi: 8), 646000);
    expect(paketTotal(pricePerSession: 85000, totalSesi: 12), 918000);
  });
}
