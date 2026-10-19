import '../booking/booking_repository.dart';

/// Status booking yang tidak dianggap "akan datang".
const _closedStatuses = {'completed', 'cancelled', 'expired', 'refunded'};

/// Sesi mendatang: belum lewat lebih dari 20 menit dan statusnya masih aktif,
/// diurutkan dari yang paling dekat.
List<BookingItem> upcomingBookings(List<BookingItem> bookings) {
  final now = DateTime.now();
  return bookings
      .where(
        (b) =>
            b.scheduledAt.isAfter(now.subtract(const Duration(minutes: 20))) &&
            !_closedStatuses.contains(b.status),
      )
      .toList()
    ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
}
