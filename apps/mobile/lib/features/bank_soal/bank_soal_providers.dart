import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';

import 'bank_soal_repository.dart';

final bankSoalRepositoryProvider = Provider<BankSoalRepository>(
  (ref) => BankSoalRepository(),
);

final planProvider = FutureProvider<PlanItem?>(
  (ref) => ref.read(bankSoalRepositoryProvider).fetchPlan(),
);

final mySubscriptionProvider = FutureProvider<SubscriptionInfo?>((ref) {
  ref.watch(authStateProvider);
  return ref.read(bankSoalRepositoryProvider).fetchMySubscription();
});

/// Statistik akurasi per topik milik siswa.
final myStatsProvider = FutureProvider<List<TopicStat>>((ref) {
  ref.watch(authStateProvider);
  return ref.read(bankSoalRepositoryProvider).fetchMyStats();
});

/// Katalog topik Bank Soal + jumlah soal per topik.
final catalogProvider = FutureProvider<List<CatalogTopic>>(
  (ref) => ref.read(bankSoalRepositoryProvider).fetchCatalog(),
);

/// Paket soal (termasuk paket coba gratis) + nilai terakhir siswa.
final packsProvider = FutureProvider<List<QuestionPack>>((ref) {
  ref.watch(authStateProvider);
  return ref.read(bankSoalRepositoryProvider).fetchPacks();
});
