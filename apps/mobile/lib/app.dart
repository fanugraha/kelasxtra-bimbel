import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme.dart';

class BimbelApp extends ConsumerWidget {
  const BimbelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Kelasxtra Bimbel',
      theme: AppTheme.light(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
