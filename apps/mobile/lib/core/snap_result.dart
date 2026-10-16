/// Hasil pemanggilan Edge Function Snap (booking per sesi maupun paket).
class SnapResult {
  const SnapResult({
    required this.orderId,
    required this.redirectUrl,
    required this.amount,
    required this.reused,
    this.bookingId,
    this.packageId,
  });

  final String orderId;
  final String redirectUrl;
  final int amount;
  final bool reused;
  final String? bookingId;
  final String? packageId;
}
