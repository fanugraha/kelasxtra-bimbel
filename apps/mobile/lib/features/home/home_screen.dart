import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/supabase_client.dart';
import '../auth/auth_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flavor = ref.watch(appFlavorProvider);
    final user = supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Kelasxtra — ${flavor.label}'),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Masuk sebagai ${flavor.label}',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(user?.email ?? '-'),
            const SizedBox(height: 24),
            const Text('Fondasi Fase 0 aktif. Fitur menyusul per fase.'),
          ],
        ),
      ),
    );
  }
}
