import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/snap_result.dart';
import '../../core/supabase_client.dart';

/// Satu booking milik siswa (untuk tab Jadwal).
class BookingItem {
  const BookingItem({
    required this.id,
    required this.tutorId,
    required this.studentId,
    required this.tutorName,
    required this.studentName,
    required this.subjectName,
    required this.jenjang,
    required this.durationMinutes,
    required this.mode,
    required this.scheduledAt,
    required this.status,
    required this.price,
    this.tutorPhotoUrl,
    this.meetingUrl,
  });

  final String id;
  final String tutorId;
  final String studentId;
  final String tutorName;
  final String studentName;
  final String subjectName;
  final String jenjang;
  final int durationMinutes;
  final String mode;
  final DateTime scheduledAt;
  final String status;
  final int price;

  /// Foto tentor untuk kartu Lapis 1 di Jadwal (boleh null → inisial).
  final String? tutorPhotoUrl;

  /// Tautan Zoom sesi daring (null bila belum diisi tentor).
  final String? meetingUrl;

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

/// Catatan tentor untuk satu sesi (materi wajib; sisanya opsional).
class SessionNote {
  const SessionNote({
    required this.material,
    this.progress,
    this.nextStep,
    this.updatedAt,
  });

  final String material;
  final String? progress;

  /// Tugas atau saran berikutnya untuk siswa.
  final String? nextStep;
  final DateTime? updatedAt;

  bool get hasAssignment => nextStep != null && nextStep!.trim().isNotEmpty;
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
    this.studentName = '-',
    this.address,
    this.checkinAt,
    this.studentAttendedAt,
    this.completedAt,
    this.refundAmount = 0,
    this.rescheduleCount = 0,
    this.hasReview = false,
    this.meetingUrl,
    this.note,
  });

  final String id;
  final String studentId;
  final String tutorId;
  final String tutorName;
  final String studentName;
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
  final bool hasReview;

  /// Tautan Zoom (hanya terbaca pasca-bayar) dan catatan tentor, bila ada.
  final String? meetingUrl;
  final SessionNote? note;

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

/// Permintaan ganti hari berpasangan untuk satu sesi.
class RescheduleRequest {
  const RescheduleRequest({
    required this.id,
    required this.bookingId,
    required this.requestedBy,
    required this.fromAt,
    required this.toAt,
    required this.status,
    required this.createdAt,
    this.reason,
    this.responseNote,
    this.respondBy,
  });

  final String id;
  final String bookingId;
  final String requestedBy;
  final DateTime fromAt;
  final DateTime toAt;
  final String status;
  final String? reason;
  final String? responseNote;
  final DateTime? respondBy;
  final DateTime createdAt;

  bool get isPending => status == 'pending';

  bool isMine(String userId) => requestedBy == userId;
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
    bool useCredits = false,
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
        if (voucherCode != null && voucherCode.isNotEmpty)
          'voucher_code': voucherCode,
        if (useCredits) 'use_credits': true,
      },
    );
    final data = _decode(res);
    if (res.status != 200) {
      throw Exception(
        data['error'] ?? 'Gagal memulai pembayaran (${res.status})',
      );
    }
    return SnapResult.fromJson(data);
  }

  Future<List<BookingItem>> fetchMyBookings({bool asTutor = false}) async {
    // Baca dari VIEW `bookings_visible`: tanpa kolom bagi hasil, `address`
    // hanya terbuka pasca-bayar, dan hanya baris milik sendiri.
    var query = supabase
        .from('bookings_visible')
        .select(
          'id, student_id, tutor_id, subject_id, jenjang, duration_minutes, mode, '
          'scheduled_at, status, price, meeting_url',
        );
    if (asTutor) {
      query = query.eq('tutor_id', supabase.auth.currentUser!.id);
    }
    final rows = await query.order('scheduled_at', ascending: false);

    if (rows.isEmpty) return [];

    final tutorIds = {for (final r in rows) r['tutor_id'] as String}.toList();
    final studentIds = {
      for (final r in rows) r['student_id'] as String,
    }.toList();
    final subjectIds = {
      for (final r in rows) r['subject_id'] as String,
    }.toList();

    final tutorRows = await supabase
        .from('tutor_catalog')
        .select('id, full_name, photo_url')
        .inFilter('id', tutorIds);
    final studentRows = await supabase
        .from('students')
        .select('id, full_name')
        .inFilter('id', studentIds);
    final subjectRows = await supabase
        .from('subjects')
        .select('id, name')
        .inFilter('id', subjectIds);

    final tutorNames = {
      for (final r in tutorRows)
        r['id'] as String: (r['full_name'] ?? '-') as String,
    };
    final tutorPhotos = {
      for (final r in tutorRows)
        if ((r['photo_url'] as String?)?.isNotEmpty ?? false)
          r['id'] as String: r['photo_url'] as String,
    };
    final studentNames = {
      for (final r in studentRows)
        r['id'] as String: (r['full_name'] ?? '-') as String,
    };
    final subjectNames = {
      for (final r in subjectRows)
        r['id'] as String: (r['name'] ?? '-') as String,
    };

    return [
      for (final r in rows)
        BookingItem(
          id: r['id'] as String,
          tutorId: r['tutor_id'] as String,
          studentId: r['student_id'] as String,
          tutorName: tutorNames[r['tutor_id']] ?? '-',
          studentName: studentNames[r['student_id']] ?? '-',
          subjectName: subjectNames[r['subject_id']] ?? '-',
          jenjang: (r['jenjang'] ?? '-') as String,
          durationMinutes: (r['duration_minutes'] as num).toInt(),
          mode: (r['mode'] ?? '-') as String,
          scheduledAt: DateTime.parse(r['scheduled_at'] as String).toLocal(),
          status: (r['status'] ?? '-') as String,
          price: (r['price'] as num).toInt(),
          tutorPhotoUrl: tutorPhotos[r['tutor_id']],
          meetingUrl: r['meeting_url'] as String?,
        ),
    ];
  }

  Future<BookingDetail> fetchBookingDetail(String id) async {
    final r = await supabase
        .from('bookings_visible')
        .select(
          'id, student_id, tutor_id, subject_id, jenjang, duration_minutes, '
          'mode, scheduled_at, status, price, address, checkin_at, '
          'student_attended_at, completed_at, refund_amount, reschedule_count, '
          'meeting_url',
        )
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
    final student = await supabase
        .from('students')
        .select('full_name')
        .eq('id', r['student_id'] as String)
        .maybeSingle();
    final review = await supabase
        .from('reviews')
        .select('id')
        .eq('booking_id', id)
        .maybeSingle();
    final note = await supabase
        .from('session_notes')
        .select('material, progress, next_step, updated_at')
        .eq('booking_id', id)
        .maybeSingle();
    return BookingDetail(
      id: r['id'] as String,
      studentId: r['student_id'] as String,
      tutorId: r['tutor_id'] as String,
      tutorName: (tutor?['full_name'] ?? '-') as String,
      studentName: (student?['full_name'] ?? '-') as String,
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
      hasReview: review != null,
      rescheduleCount: (r['reschedule_count'] as num?)?.toInt() ?? 0,
      meetingUrl: r['meeting_url'] as String?,
      note: note == null
          ? null
          : SessionNote(
              material: (note['material'] ?? '') as String,
              progress: note['progress'] as String?,
              nextStep: note['next_step'] as String?,
              updatedAt: note['updated_at'] == null
                  ? null
                  : DateTime.parse(note['updated_at'] as String).toLocal(),
            ),
    );
  }

  Future<dynamic> _rpc(String fn, Map<String, dynamic> params) async {
    try {
      return await supabase.rpc(fn, params: params);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> checkin(String bookingId, {double? lat, double? lng}) => _rpc(
    'tutor_checkin',
    {'p_booking': bookingId, 'p_lat': lat, 'p_lng': lng},
  );

  Future<void> studentAttend(String bookingId) =>
      _rpc('student_attend', {'p_booking': bookingId});

  Future<void> markNoShow(String bookingId, String who) =>
      _rpc('mark_no_show', {'p_booking': bookingId, 'p_who': who});

  /// Simpan catatan sesi. `material` wajib; sisanya boleh kosong.
  Future<void> saveNote(
    String bookingId,
    String material,
    String progress, {
    String? nextStep,
  }) => _rpc('save_session_note', {
    'p_booking': bookingId,
    'p_material': material,
    'p_progress': progress,
    'p_next_step': nextStep,
  });

  /// Isi/hapus tautan Zoom sesi (khusus tutor pemilik, sesi online).
  Future<void> setMeetingUrl(String bookingId, String? url) =>
      _rpc('set_session_meeting_url', {
        'p_booking': bookingId,
        'p_url': (url == null || url.trim().isEmpty) ? null : url.trim(),
      });

  Future<void> complete(String bookingId) =>
      _rpc('complete_booking', {'p_booking': bookingId});

  /// Ajukan ganti hari (butuh persetujuan pihak lain). Melempar bila ditolak.
  Future<void> requestReschedule(
    String bookingId,
    DateTime newAt,
    String reason,
  ) => _rpc('request_reschedule', {
    'p_booking': bookingId,
    'p_new_at': newAt.toUtc().toIso8601String(),
    'p_reason': reason,
  });

  Future<void> respondReschedule(
    String requestId, {
    required bool accept,
    String? note,
  }) => _rpc('respond_reschedule', {
    'p_request': requestId,
    'p_accept': accept,
    'p_note': (note == null || note.trim().isEmpty) ? null : note.trim(),
  });

  Future<void> cancelRescheduleRequest(String requestId) =>
      _rpc('cancel_reschedule_request', {'p_request': requestId});

  /// Tutor menjadwalkan ulang pertemuan paket yang gagal (no-show tutor).
  Future<void> rescheduleNoShow(
    String bookingId,
    DateTime newAt,
    String reason,
  ) => _rpc('reschedule_no_show', {
    'p_booking': bookingId,
    'p_new_at': newAt.toUtc().toIso8601String(),
    'p_reason': reason,
  });

  Future<List<RescheduleRequest>> fetchRescheduleRequests(
    String bookingId,
  ) async {
    final rows = await supabase
        .from('reschedule_requests')
        .select(
          'id, booking_id, requested_by, from_at, to_at, reason, status, '
          'response_note, respond_by, created_at',
        )
        .eq('booking_id', bookingId)
        .order('created_at', ascending: false);
    return [
      for (final r in rows)
        RescheduleRequest(
          id: r['id'] as String,
          bookingId: r['booking_id'] as String,
          requestedBy: r['requested_by'] as String,
          fromAt: DateTime.parse(r['from_at'] as String).toLocal(),
          toAt: DateTime.parse(r['to_at'] as String).toLocal(),
          status: (r['status'] ?? '-') as String,
          reason: r['reason'] as String?,
          responseNote: r['response_note'] as String?,
          respondBy: r['respond_by'] == null
              ? null
              : DateTime.parse(r['respond_by'] as String).toLocal(),
          createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
        ),
    ];
  }

  /// Saldo poin siswa yang sedang masuk (1 poin = Rp1).
  Future<int> myCreditBalance() async {
    final data = await _rpc('my_credit_balance', const {});
    return (data as num?)?.toInt() ?? 0;
  }

  Future<void> review(String bookingId, int rating, String comment) => _rpc(
    'submit_review',
    {'p_booking': bookingId, 'p_rating': rating, 'p_comment': comment},
  );

  Future<void> complain(String bookingId, String category, String body) => _rpc(
    'open_complaint',
    {'p_booking': bookingId, 'p_category': category, 'p_body': body},
  );

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
