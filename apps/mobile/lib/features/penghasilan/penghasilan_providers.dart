import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';

import 'penghasilan_repository.dart';

final penghasilanRepositoryProvider = Provider<PenghasilanRepository>(
  (ref) => PenghasilanRepository(),
);

final myPayoutsProvider = FutureProvider<List<PayoutItem>>((ref) {
  ref.watch(authStateProvider);
  return ref.read(penghasilanRepositoryProvider).fetchMyPayouts();
});
