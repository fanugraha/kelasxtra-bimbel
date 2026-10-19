import 'package:bimbel_mobile/features/bank_soal/widgets/math_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('math widgets dirender dan punya ukuran', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MathText('Nilai dari tan 45 derajat adalah ...')),
      ),
    );
    await tester.pumpAndSettle();
    final math = find.byType(Math);
    expect(math, findsOneWidget);
    expect(tester.getSize(math).width, greaterThan(0));
  });

  testWidgets('opsi matematika utuh dirender sebagai satu rumus', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MathText('akar3/2'))),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Math), findsOneWidget);
    expect(tester.getSize(find.byType(Math)).width, greaterThan(0));
  });
}
