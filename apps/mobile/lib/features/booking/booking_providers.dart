import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final bookingDetailProvider =
    FutureProvider.family<BookingDetail, String>((ref, id) {
  return ref.read(bookingRepositoryProvider).fetchBookingDetail(id);
});

final bookingMessagesProvider =
    FutureProvider.family<List<ChatMessage>, String>((ref, id) {
  return ref.read(bookingRepositoryProvider).fetchMessages(id);
});
