/// Hasil pemanggilan Edge Function pembayaran (booking per sesi, paket, kursi
/// kelas grup, maupun langganan). Tagihan dibayar lewat QRIS dinamis.
class SnapResult {
  const SnapResult({
    required this.orderId,
    required this.amount,
    required this.reused,
    this.qrString = '',
    this.qrUrl = '',
    this.snapUrl = '',
    this.expiresAt,
    this.bookingId,
    this.packageId,
    this.creditApplied = 0,
    this.paid = false,
  });

  factory SnapResult.fromJson(Map<String, dynamic> map) {
    final expires = map['expires_at'] as String?;
    return SnapResult(
      orderId: map['order_id'] as String,
      amount: (map['amount'] as num).toInt(),
      reused: (map['reused'] ?? false) as bool,
      qrString: (map['qr_string'] ?? '') as String,
      qrUrl: (map['qr_url'] ?? '') as String,
      snapUrl: (map['snap_url'] ?? '') as String,
      expiresAt: expires == null ? null : DateTime.tryParse(expires)?.toLocal(),
      bookingId: map['booking_id'] as String?,
      packageId: map['package_id'] as String?,
      creditApplied: (map['credit_applied'] as num?)?.toInt() ?? 0,
      paid: (map['paid'] ?? false) as bool,
    );
  }

  final String orderId;
  final int amount;
  final bool reused;

  /// Isi QRIS (nominal sudah tertanam); kosong bila lunas penuh oleh poin.
  final String qrString;

  /// URL gambar QR dari Midtrans, cadangan bila [qrString] kosong.
  final String qrUrl;

  /// Halaman Snap (GoPay/QRIS saja) — cadangan bila kanal QRIS Core API belum
  /// aktif; terisi hanya bila [qrString] & [qrUrl] kosong.
  final String snapUrl;

  /// Batas waktu bayar QRIS.
  final DateTime? expiresAt;

  final String? bookingId;
  final String? packageId;

  /// Poin (Rp) yang dipakai memotong tagihan ini.
  final int creditApplied;

  /// True bila tagihan lunas penuh oleh poin (tanpa Midtrans).
  final bool paid;
}
