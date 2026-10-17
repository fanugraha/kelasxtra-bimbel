import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/snap_result.dart';
import '../../core/supabase_client.dart';

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

/// Detail satu sesi untuk layar aksi (absensi, reschedule, komplain, chat).
class BookingDetail {
  const BookingDetail({
    required this.id,
    required this.studentId,
    required this.tutorId,
    required this.tutorName,
    required this.subjectName,
    required this.jenjang,
    required this.durationMinutes,
    required this.mode,
    required this.scheduledAt,
    required this.status,
    required this.price,
    this.address,
    this.checkinAt,
    this.studentAttendedAt,
    this.completedAt,
    this.refundAmount = 0,
    this.rescheduleCount = 0,
  });

  final String id;
  final String studentId;
  final String tutorId;
  final String tutorName;
  final String subjectName;
  final String jenjang;
  final int durationMinutes;
  final String mode;
  final DateTime scheduledAt;
  final String status;
  final int price;
  final String? address;
  final DateTime? checkinAt;
  final DateTime? studentAttendedAt;
  final DateTime? completedAt;
  final int refundAmount;
  final int rescheduleCount;

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
        _ => status,
      };
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.flagged,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String body;
  final bool flagged;
  final DateTime createdAt;
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
      bookingId: data['booking_id'] as String?,
      redirectUrl: data['redirect_url'] as String,
      amount: (data['amount'] as num).toInt(),
      reused: (data['reused'] ?? false) as bool,
    );
  }

  Future<List<BookingItem>> fetchMyBookings({bool asTutor = false}) async {
    // Baca dari VIEW `bookings_visible`: tanpa kolom bagi hasil, `address`
    // hanya terbuka pasca-bayar, dan hanya baris milik sendiri.
    var query = supabase
        .from('bookings_visible')
        .select('id, tutor_id, subject_id, jenjang, duration_minutes, mode, '
            'scheduled_at, status, price');
    if (asTutor) {
      query = query.eq('tutor_id', supabase.auth.currentUser!.id);
    }
    final rows = await query.order('scheduled_at', ascending: false);

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

  Future<BookingDetail> fetchBookingDetail(String id) async {
    final r = await supabase
        .from('bookings_visible')
        .select('id, student_id, tutor_id, subject_id, jenjang, duration_minutes, '
            'mode, scheduled_at, status, price, address, checkin_at, '
            'student_attended_at, completed_at, refund_amount, reschedule_count')
        .eq('id', id)
        .single();
    final tutor = await supabase
        .from('tutor_catalog')
        .select('full_name')
        .eq('id', r['tutor_id'] as String)
        .maybeSingle();
    final subject = await supabase
        .from('subjects')
        .select('name')
        .eq('id', r['subject_id'] as String)
        .maybeSingle();
    return BookingDetail(
      id: r['id'] as String,
      studentId: r['student_id'] as String,
      tutorId: r['tutor_id'] as String,
      tutorName: (tutor?['full_name'] ?? '-') as String,
      subjectName: (subject?['name'] ?? '-') as String,
      jenjang: (r['jenjang'] ?? '-') as String,
      durationMinutes: (r['duration_minutes'] as num).toInt(),
      mode: (r['mode'] ?? '-') as String,
      scheduledAt: DateTime.parse(r['scheduled_at'] as String).toLocal(),
      status: (r['status'] ?? '-') as String,
      price: (r['price'] as num).toInt(),
      address: r['address'] as String?,
      checkinAt: r['checkin_at'] == null
          ? null
          : DateTime.parse(r['checkin_at'] as String).toLocal(),
      studentAttendedAt: r['student_attended_at'] == null
          ? null
          : DateTime.parse(r['student_attended_at'] as String).toLocal(),
      completedAt: r['completed_at'] == null
          ? null
          : DateTime.parse(r['completed_at'] as String).toLocal(),
      refundAmount: (r['refund_amount'] as num?)?.toInt() ?? 0,
      rescheduleCount: (r['reschedule_count'] as num?)?.toInt() ?? 0,
    );
  }

  Future<dynamic> _rpc(String fn, Map<String, dynamic> params) async {
    try {
      return await supabase.rpc(fn, params: params);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> checkin(String bookingId, {double? lat, double? lng}) =>
      _rpc('tutor_checkin', {
        'p_booking': bookingId,
        'p_lat': lat,
        'p_lng': lng,
      });

  Future<void> studentAttend(String bookingId) =>
      _rpc('student_attend', {'p_booking': bookingId});

  Future<void> markNoShow(String bookingId, String who) =>
      _rpc('mark_no_show', {'p_booking': bookingId, 'p_who': who});

  Future<void> saveNote(String bookingId, String material, String progress) =>
      _rpc('save_session_note', {
        'p_booking': bookingId,
        'p_material': material,
        'p_progress': progress,
      });

  Future<void> complete(String bookingId) =>
      _rpc('complete_booking', {'p_booking': bookingId});

  Future<void> reschedule(String bookingId, DateTime newAt, String reason) =>
      _rpc('reschedule_booking', {
        'p_booking': bookingId,
        'p_new_at': newAt.toUtc().toIso8601String(),
        'p_reason': reason,
      });

  Future<Map<String, dynamic>> cancel(String bookingId, String reason) async {
    final res = await _rpc('cancel_booking', {
      'p_booking': bookingId,
      'p_reason': reason,
    });
    return (res as Map).cast<String, dynamic>();
  }

  Future<void> review(String bookingId, int rating, String comment) =>
      _rpc('submit_review', {
        'p_booking': bookingId,
        'p_rating': rating,
        'p_comment': comment,
      });

  Future<void> complain(String bookingId, String category, String body) =>
      _rpc('open_complaint', {
        'p_booking': bookingId,
        'p_category': category,
        'p_body': body,
      });

  Future<List<ChatMessage>> fetchMessages(String bookingId) async {
    final thread = await supabase
        .from('booking_threads')
        .select('id')
        .eq('booking_id', bookingId)
        .maybeSingle();
    if (thread == null) return [];
    final rows = await supabase
        .from('thread_messages')
        .select('id, sender_id, body, flagged, created_at')
        .eq('thread_id', thread['id'] as String)
        .order('created_at');
    return [
      for (final r in rows)
        ChatMessage(
          id: r['id'] as String,
          senderId: r['sender_id'] as String,
          body: (r['body'] ?? '') as String,
          flagged: (r['flagged'] ?? false) as bool,
          createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
        ),
    ];
  }

  Future<void> sendMessage(String bookingId, String body) =>
      _rpc('send_booking_message', {'p_booking': bookingId, 'p_body': body});

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
