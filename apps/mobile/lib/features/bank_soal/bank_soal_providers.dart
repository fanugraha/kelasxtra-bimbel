import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bank_soal_repository.dart';

final bankSoalRepositoryProvider = Provider<BankSoalRepository>(
  (ref) => BankSoalRepository(),
);

final planProvider = FutureProvider<PlanItem?>(
  (ref) => ref.read(bankSoalRepositoryProvider).fetchPlan(),
);

final mySubscriptionProvider = FutureProvider<SubscriptionInfo?>(
  (ref) => ref.read(bankSoalRepositoryProvider).fetchMySubscription(),
);

/// Topik yang bisa dilatih.
final topicsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.read(bankSoalRepositoryProvider).fetchTopics(),
);

/// Statistik akurasi per topik milik siswa.
final myStatsProvider = FutureProvider<List<TopicStat>>(
  (ref) => ref.read(bankSoalRepositoryProvider).fetchMyStats(),
);
