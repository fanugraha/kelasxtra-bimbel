import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';

import 'riwayat_repository.dart';

final riwayatRepositoryProvider = Provider<RiwayatRepository>(
  (ref) => RiwayatRepository(),
);

/// Riwayat transaksi siswa (paket, sesi, langganan, kelas grup).
final riwayatProvider = FutureProvider<List<TransaksiItem>>((ref) {
  ref.watch(authStateProvider);
  return ref.read(riwayatRepositoryProvider).fetchRiwayat();
});
