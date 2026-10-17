import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'penghasilan_repository.dart';

final penghasilanRepositoryProvider = Provider<PenghasilanRepository>(
  (ref) => PenghasilanRepository(),
);

final myPayoutsProvider = FutureProvider<List<PayoutItem>>(
  (ref) => ref.read(penghasilanRepositoryProvider).fetchMyPayouts(),
);
