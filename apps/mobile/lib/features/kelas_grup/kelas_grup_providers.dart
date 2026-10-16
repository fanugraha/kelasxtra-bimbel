import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'kelas_grup_repository.dart';

final kelasGrupRepositoryProvider = Provider<KelasGrupRepository>(
  (ref) => KelasGrupRepository(),
);

/// Semua program kelas grup yang dibuka/dikonfirmasi.
final groupClassesProvider = FutureProvider<List<GroupClassItem>>(
  (ref) => ref.read(kelasGrupRepositoryProvider).fetchClasses(),
);

final groupClassProvider = FutureProvider.family<GroupClassItem?, String>(
  (ref, id) => ref.read(kelasGrupRepositoryProvider).fetchClass(id),
);

final groupSessionsProvider = FutureProvider.family<List<GroupSessionItem>, String>(
  (ref, id) => ref.read(kelasGrupRepositoryProvider).fetchSessions(id),
);

/// Kursi siswa (semua program).
final myGroupSeatsProvider = FutureProvider<List<GroupSeatItem>>(
  (ref) => ref.read(kelasGrupRepositoryProvider).fetchMySeats(),
);

/// Kursi siswa di satu program (null bila belum ambil).
final myGroupSeatProvider = FutureProvider.family<GroupSeatItem?, String>(
  (ref, id) => ref.read(kelasGrupRepositoryProvider).fetchMySeat(id),
);
