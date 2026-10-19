import 'package:bimbel_mobile/core/theme/app_theme.dart';
import 'package:bimbel_mobile/features/home/siswa/widgets/promo_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

int _page(WidgetTester tester) =>
    tester.widget<PageView>(find.byType(PageView)).controller!.page!.round();

void main() {
  testWidgets('karusel promo bergeser otomatis lalu kembali ke awal', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: PromoCarousel()),
      ),
    );
    expect(_page(tester), 0);

    for (final expected in [1, 2, 0]) {
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(_page(tester), expected);
    }
  });

  testWidgets('diam bila animasi dimatikan di pengaturan', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: PromoCarousel()),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
    expect(_page(tester), 0);
  });
}
