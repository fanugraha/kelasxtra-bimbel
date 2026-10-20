import 'dart:io';

import 'package:bimbel_mobile/core/app_flavor.dart';
import 'package:bimbel_mobile/core/providers.dart';
import 'package:bimbel_mobile/core/theme/app_theme.dart';
import 'package:bimbel_mobile/features/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

const _buttonText = TextStyle(
  fontFamily: 'Roboto',
  fontSize: 15,
  fontWeight: FontWeight.w700,
);

Widget _frame(AppFlavor flavor, ThemeData theme) => SizedBox(
  width: 390,
  height: 844,
  child: ProviderScope(
    overrides: [appFlavorProvider.overrideWithValue(flavor)],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      // Tes tak boleh mengunduh font: pakai Roboto & ikon bawaan SDK Flutter.
      theme: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
        filledButtonTheme: FilledButtonThemeData(
          style: theme.filledButtonTheme.style?.copyWith(
            textStyle: const WidgetStatePropertyAll(_buttonText),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: theme.textButtonTheme.style?.copyWith(
            textStyle: const WidgetStatePropertyAll(_buttonText),
          ),
        ),
      ),
      home: const LoginScreen(),
    ),
  ),
);

Future<void> _loadFont(String family, List<String> files) async {
  final dir = '${Platform.environment['FLUTTER_ROOT']}'
      '/bin/cache/artifacts/material_fonts';
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = File('$dir/$f').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadFont('Roboto', [
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
      'Roboto-Black.ttf',
    ]);
    await _loadFont('MaterialIcons', ['MaterialIcons-Regular.otf']);
  });

  testWidgets('preview login', (tester) async {
    tester.view.physicalSize = const Size(1170, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            _frame(AppFlavor.siswa, AppTheme.light()),
            _frame(AppFlavor.siswa, AppTheme.dark()),
            _frame(AppFlavor.tutor, AppTheme.light()),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await expectLater(
      find.byType(Row).first,
      matchesGoldenFile('goldens/login_preview.png'),
    );
  }, skip: !Platform.isMacOS);
}
