import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'paket_repository.dart';

final paketRepositoryProvider = Provider<PaketRepository>(
  (ref) => PaketRepository(),
);

/// Semua paket milik siswa (untuk layar "Paket Saya").
final myPackagesProvider = FutureProvider<List<PackageItem>>(
  (ref) => ref.read(paketRepositoryProvider).fetchMyPackages(),
);

/// Paket aktif untuk tutor tertentu (dipakai booking pakai-kuota).
final activePackagesForTutorProvider =
    FutureProvider.family<List<PackageItem>, String>((ref, tutorId) {
  return ref.read(paketRepositoryProvider).fetchActiveForTutor(tutorId);
});

/// Ukuran paket yang tersedia beserta diskonnya.
const paketSizes = <int, int>{4: 0, 8: 5, 12: 10};

/// Total harga paket (dibulatkan ke bawah, integer rupiah).
int paketTotal({required int pricePerSession, required int totalSesi}) {
  final diskon = paketSizes[totalSesi] ?? 0;
  return (pricePerSession * totalSesi * (100 - diskon)) ~/ 100;
}
