import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mode tema aplikasi. Disimpan di memori selama aplikasi berjalan.
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  bool isDark(BuildContext context) {
    if (state == ThemeMode.dark) return true;
    if (state == ThemeMode.light) return false;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }

  void toggle(BuildContext context) {
    state = isDark(context) ? ThemeMode.light : ThemeMode.dark;
  }
}
