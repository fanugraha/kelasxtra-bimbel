import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import 'app_flavor.dart';
import 'env.dart';
import 'providers.dart';
import 'supabase_client.dart';

/// Titik masuk bersama untuk kedua flavor.
Future<void> bootstrap(AppFlavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Env.isConfigured) {
    runApp(const _MissingConfigApp());
    return;
  }
  await initSupabase();
  runApp(
    ProviderScope(
      overrides: [appFlavorProvider.overrideWithValue(flavor)],
      child: const BimbelApp(),
    ),
  );
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'SUPABASE_URL / SUPABASE_ANON_KEY belum di-set.\n'
              'Jalankan dengan --dart-define (lihat README).',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
