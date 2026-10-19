import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';

import 'absensi_grup_repository.dart';

final groupAttendanceRepositoryProvider = Provider<GroupAttendanceRepository>(
  (ref) => GroupAttendanceRepository(),
);

final groupAttendanceProvider = FutureProvider<List<GroupAttendanceRow>>((ref) {
  ref.watch(authStateProvider);
  return ref.read(groupAttendanceRepositoryProvider).fetchRows();
});
