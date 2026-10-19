import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';

import 'paket_repository.dart';

final paketRepositoryProvider = Provider<PaketRepository>(
  (ref) => PaketRepository(),
);

/// Semua paket milik siswa (untuk layar "Paket Saya").
final myPackagesProvider = FutureProvider<List<PackageItem>>((ref) {
  ref.watch(authStateProvider);
  return ref.read(paketRepositoryProvider).fetchMyPackages();
});

/// Slot sibuk tutor (dan milik siswa) untuk menyaring pilihan jadwal.
final tutorBusyProvider = FutureProvider.family<List<BusySlot>, String>((
  ref,
  tutorId,
) {
  return ref.read(paketRepositoryProvider).fetchBusySlots(tutorId);
});

/// Jumlah pertemuan yang bisa dibeli (seminggu sekali).
const paketSizeOptions = [4, 8, 12];

/// Label panjang: "8 pertemuan · 2 bulan".
String paketSizeLabel(int totalSesi) =>
    '$totalSesi pertemuan · ${paketMasaBerlaku(totalSesi)}';

/// Masa berlaku paket mengikuti jumlah pertemuan.
String paketMasaBerlaku(int totalSesi) => switch (totalSesi) {
  4 => '1 bulan',
  8 => '2 bulan',
  _ => '3 bulan',
};

/// Harga paket untuk satu kombinasi (ditetapkan admin). Null bila belum diset.
typedef PackagePriceArgs = ({
  String jenjang,
  int duration,
  String mode,
  int totalSesi,
});

final packagePriceProvider = FutureProvider.family<int?, PackagePriceArgs>((
  ref,
  args,
) {
  return ref
      .read(paketRepositoryProvider)
      .fetchPackagePrice(
        jenjang: args.jenjang,
        durationMinutes: args.duration,
        mode: args.mode,
        totalSesi: args.totalSesi,
      );
});

/// Harga paket per pertemuan (untuk info "setara Rp …/pertemuan").
int? paketPerSesi(int? hargaPaket, int totalSesi) =>
    hargaPaket == null ? null : hargaPaket ~/ totalSesi;
