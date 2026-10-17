import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_flavor.dart';
import '../../core/providers.dart';
import 'booking_repository.dart';

final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => BookingRepository(),
);

typedef PriceQuery = ({String jenjang, int duration, String mode});

/// Harga privat untuk kombinasi jenjang/durasi/mode (null bila belum diset).
final priceProvider = FutureProvider.family<int?, PriceQuery>((ref, q) {
  return ref.read(bookingRepositoryProvider).fetchPrice(
        jenjang: q.jenjang,
        durationMinutes: q.duration,
        mode: q.mode,
      );
});

/// Daftar booking milik siswa yang sedang login.
final myBookingsProvider = FutureProvider<List<BookingItem>>((ref) {
  return ref.read(bookingRepositoryProvider).fetchMyBookings();
});

/// Daftar sesi yang diampu tutor yang sedang login.
final tutorBookingsProvider = FutureProvider<List<BookingItem>>((ref) {
  return ref.read(bookingRepositoryProvider).fetchMyBookings(asTutor: true);
});

/// Pilih sumber jadwal sesuai flavor aplikasi.
final jadwalProvider = FutureProvider<List<BookingItem>>((ref) {
  final flavor = ref.watch(appFlavorProvider);
  return flavor == AppFlavor.tutor
      ? ref.watch(tutorBookingsProvider.future)
      : ref.watch(myBookingsProvider.future);
});

final bookingDetailProvider =
    FutureProvider.family<BookingDetail, String>((ref, id) {
  return ref.read(bookingRepositoryProvider).fetchBookingDetail(id);
});

final bookingMessagesProvider =
    FutureProvider.family<List<ChatMessage>, String>((ref, id) {
  return ref.read(bookingRepositoryProvider).fetchMessages(id);
});
