import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';

/// Hasil pemanggilan Edge Function `create-snap`.
class SnapResult {
  const SnapResult({
    required this.orderId,
    required this.bookingId,
    required this.redirectUrl,
    required this.amount,
    required this.reused,
  });

  final String orderId;
  final String bookingId;
  final String redirectUrl;
  final int amount;
  final bool reused;
}

/// Satu booking milik siswa (untuk tab Jadwal).
class BookingItem {
  const BookingItem({
    required this.id,
    required this.tutorName,
    required this.subjectName,
    required this.jenjang,
    required this.durationMinutes,
    required this.mode,
    required this.scheduledAt,
    required this.status,
    required this.price,
  });

  final String id;
  final String tutorName;
  final String subjectName;
  final String jenjang;
  final int durationMinutes;
  final String mode;
  final DateTime scheduledAt;
  final String status;
  final int price;

  String get statusLabel => switch (status) {
        'pending_payment' => 'Menunggu bayar',
        'confirmed' => 'Terkonfirmasi',
        'in_progress' => 'Berlangsung',
        'completed' => 'Selesai',
        'cancelled' => 'Dibatalkan',
        'expired' => 'Kedaluwarsa',
        'no_show_tutor' => 'Tutor tidak hadir',
        'no_show_student' => 'Siswa tidak hadir',
        'disputed' => 'Sengketa',
        'refunded' => 'Dana dikembalikan',
        'rescheduled' => 'Dijadwalkan ulang',
        _ => status,
      };
}

class BookingRepository {
  /// Harga aktif dari `price_matrix` (privat). Null bila belum diset admin.
  Future<int?> fetchPrice({
    required String jenjang,
    required int durationMinutes,
    required String mode,
  }) async {
    final row = await supabase
        .from('price_matrix')
        .select('price')
        .eq('jenjang', jenjang)
        .eq('duration_minutes', durationMinutes)
        .eq('mode', mode)
        .eq('type', 'privat')
        .eq('active', true)
        .maybeSingle();
    if (row == null) return null;
    return (row['price'] as num).toInt();
  }

  /// Pratinjau diskon voucher (tanpa mengunci kuota). Melempar bila kode ditolak.
  Future<int> checkVoucher({required String code, required int price}) async {
    try {
      final data = await supabase.rpc(
        'check_voucher',
        params: {'p_code': code, 'p_price': price},
      );
      return (data as num).toInt();
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Buat booking + transaksi Snap lewat Edge Function.
  Future<SnapResult> createSnap({
    required String tutorId,
    required String subjectId,
    required String jenjang,
    required int durationMinutes,
    required String mode,
    required DateTime scheduledAt,
    String? address,
    String? voucherCode,
  }) async {
    final res = await supabase.functions.invoke(
      'create-snap',
      body: {
        'tutor_id': tutorId,
        'subject_id': subjectId,
        'jenjang': jenjang,
        'duration_minutes': durationMinutes,
        'mode': mode,
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        if (address != null && address.isNotEmpty) 'address': address,
        if (voucherCode != null && voucherCode.isNotEmpty) 'voucher_code': voucherCode,
      },
    );
    final data = _decode(res);
    if (res.status != 200) {
      throw Exception(data['error'] ?? 'Gagal memulai pembayaran (${res.status})');
    }
    return SnapResult(
      orderId: data['order_id'] as String,
      bookingId: data['booking_id'] as String,
      redirectUrl: data['redirect_url'] as String,
      amount: (data['amount'] as num).toInt(),
      reused: (data['reused'] ?? false) as bool,
    );
  }

  Future<List<BookingItem>> fetchMyBookings() async {
    // Baca dari VIEW `bookings_visible`: tanpa kolom bagi hasil, `address`
    // hanya terbuka pasca-bayar, dan hanya baris milik sendiri.
    final rows = await supabase
        .from('bookings_visible')
        .select('id, tutor_id, subject_id, jenjang, duration_minutes, mode, '
            'scheduled_at, status, price')
        .order('scheduled_at', ascending: false);

    if (rows.isEmpty) return [];

    final tutorIds = {for (final r in rows) r['tutor_id'] as String}.toList();
    final subjectIds = {for (final r in rows) r['subject_id'] as String}.toList();

    final tutorRows = await supabase
        .from('tutor_catalog')
        .select('id, full_name')
        .inFilter('id', tutorIds);
    final subjectRows = await supabase
        .from('subjects')
        .select('id, name')
        .inFilter('id', subjectIds);

    final tutorNames = {
      for (final r in tutorRows) r['id'] as String: (r['full_name'] ?? '-') as String,
    };
    final subjectNames = {
      for (final r in subjectRows) r['id'] as String: (r['name'] ?? '-') as String,
    };

    return [
      for (final r in rows)
        BookingItem(
          id: r['id'] as String,
          tutorName: tutorNames[r['tutor_id']] ?? '-',
          subjectName: subjectNames[r['subject_id']] ?? '-',
          jenjang: (r['jenjang'] ?? '-') as String,
          durationMinutes: (r['duration_minutes'] as num).toInt(),
          mode: (r['mode'] ?? '-') as String,
          scheduledAt: DateTime.parse(r['scheduled_at'] as String).toLocal(),
          status: (r['status'] ?? '-') as String,
          price: (r['price'] as num).toInt(),
        ),
    ];
  }

  Map<String, dynamic> _decode(FunctionResponse res) {
    final raw = res.data;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    }
    return const {};
  }
}
