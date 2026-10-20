import '../../core/snap_result.dart';
import '../../core/supabase_client.dart';

/// Program kelas grup (jadwal tetap, maks 5 kursi).
class GroupClassItem {
  const GroupClassItem({
    required this.id,
    required this.jenjang,
    required this.mode,
    required this.durationMinutes,
    required this.totalSesi,
    required this.discountPercent,
    required this.pricePerSession,
    required this.priceTotal,
    required this.minSeats,
    required this.maxSeats,
    required this.seatsTaken,
    required this.status,
    required this.minConfirmDeadline,
    this.tutorName,
    this.subjectName,
    this.firstSession,
    this.lastSession,
    this.tutorId,
    this.seatsPaid,
    this.seatsHeld = 0,
    this.tutorPhotoUrl,
    this.tutorEducation,
    this.tutorRating,
    this.tutorBio,
  });

  final String id;
  final String jenjang;
  final String mode;
  final int durationMinutes;
  final int totalSesi;
  final int discountPercent;
  final int pricePerSession;
  final int priceTotal;
  final int minSeats;
  final int maxSeats;
  final int seatsTaken;
  final String status;
  final DateTime minConfirmDeadline;
  final String? tutorName;
  final String? subjectName;
  final DateTime? firstSession;
  final DateTime? lastSession;
  final String? tutorId;

  /// Kursi LUNAS (yang tampil sebagai "terisi"). Null pada data lama →
  /// jatuh ke [seatsTaken].
  final int? seatsPaid;

  /// Kursi yang sedang ditahan siswa lain (≤ 5 menit, belum bayar).
  final int seatsHeld;
  final String? tutorPhotoUrl;
  final String? tutorEducation;
  final double? tutorRating;
  final String? tutorBio;

  bool get dibuka => status == 'open';

  /// Kursi yang bisa diambil sekarang (kapasitas − lunas − ditahan).
  int get sisaKursi => maxSeats - seatsTaken;
  bool get penuh => seatsTaken >= maxSeats;

  /// Terisi = sudah lunas saja.
  int get terisi => seatsPaid ?? seatsTaken;

  /// Semua sisa kursi sedang ditahan orang lain (bisa kosong lagi ≤ 5 menit).
  bool get tertahanSemua => penuh && terisi < maxSeats;

  factory GroupClassItem.fromMap(Map<String, dynamic> m) => GroupClassItem(
    id: m['id'] as String,
    jenjang: (m['jenjang'] ?? '-') as String,
    mode: (m['mode'] ?? '-') as String,
    durationMinutes: (m['duration_minutes'] as num).toInt(),
    totalSesi: (m['total_sesi'] as num).toInt(),
    discountPercent: (m['discount_percent'] as num).toInt(),
    pricePerSession: (m['price_per_session'] as num).toInt(),
    priceTotal: (m['price_total'] as num).toInt(),
    minSeats: (m['min_seats'] as num).toInt(),
    maxSeats: (m['max_seats'] as num).toInt(),
    seatsTaken: (m['seats_taken'] as num).toInt(),
    status: (m['status'] ?? '-') as String,
    minConfirmDeadline: DateTime.parse(
      m['min_confirm_deadline'] as String,
    ).toLocal(),
    tutorName: m['tutor_name'] as String?,
    subjectName: m['subject_name'] as String?,
    firstSession: m['first_session'] == null
        ? null
        : DateTime.parse(m['first_session'] as String).toLocal(),
    lastSession: m['last_session'] == null
        ? null
        : DateTime.parse(m['last_session'] as String).toLocal(),
    tutorId: m['tutor_id'] as String?,
    seatsPaid: (m['seats_paid'] as num?)?.toInt(),
    seatsHeld: (m['seats_held'] as num?)?.toInt() ?? 0,
    tutorPhotoUrl: m['tutor_photo_url'] as String?,
    tutorEducation: m['tutor_education'] as String?,
    tutorRating: (m['tutor_rating'] as num?)?.toDouble(),
    tutorBio: m['tutor_bio'] as String?,
  );
}

class GroupSessionItem {
  const GroupSessionItem({required this.seq, required this.scheduledAt});
  final int seq;
  final DateTime scheduledAt;

  factory GroupSessionItem.fromMap(Map<String, dynamic> m) => GroupSessionItem(
    seq: (m['seq'] as num).toInt(),
    scheduledAt: DateTime.parse(m['scheduled_at'] as String).toLocal(),
  );
}

/// Kursi siswa di sebuah program.
class GroupSeatItem {
  const GroupSeatItem({
    required this.id,
    required this.groupClassId,
    required this.pricePaid,
    required this.status,
    this.refundAmount,
    this.lockExpiresAt,
  });

  final String id;
  final String groupClassId;
  final int pricePaid;
  final String status;
  final int? refundAmount;

  /// Batas tahanan kursi (hanya untuk `pending_payment`).
  final DateTime? lockExpiresAt;

  /// Masih ditahan untuk siswa ini dan belum lewat 5 menit.
  bool get holdAlive =>
      status == 'pending_payment' &&
      lockExpiresAt != null &&
      lockExpiresAt!.isAfter(DateTime.now());

  String get statusLabel => switch (status) {
    'pending_payment' => 'Menunggu bayar',
    'active' => 'Aktif',
    'refund_pending' => 'Menunggu refund',
    'refunded' => 'Dana dikembalikan',
    'cancelled' => 'Dibatalkan',
    _ => status,
  };

  factory GroupSeatItem.fromMap(Map<String, dynamic> m) => GroupSeatItem(
    id: m['id'] as String,
    groupClassId: m['group_class_id'] as String,
    pricePaid: (m['price_paid'] as num).toInt(),
    status: (m['status'] ?? '-') as String,
    refundAmount: (m['refund_amount'] as num?)?.toInt(),
    lockExpiresAt: m['lock_expires_at'] == null
        ? null
        : DateTime.parse(m['lock_expires_at'] as String).toLocal(),
  );
}

class KelasGrupRepository {
  static const _classCols =
      'id, jenjang, mode, duration_minutes, total_sesi, discount_percent, '
      'price_per_session, price_total, min_seats, max_seats, seats_taken, '
      'status, min_confirm_deadline, tutor_name, subject_name, '
      'first_session, last_session, tutor_id, seats_paid, seats_held, '
      'tutor_photo_url, tutor_education, tutor_rating, tutor_bio';

  Future<List<GroupClassItem>> fetchClasses() async {
    final rows = await supabase
        .from('group_classes_visible')
        .select(_classCols)
        .order('min_confirm_deadline');
    return rows.map(GroupClassItem.fromMap).toList();
  }

  Future<GroupClassItem?> fetchClass(String id) async {
    final row = await supabase
        .from('group_classes_visible')
        .select(_classCols)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : GroupClassItem.fromMap(row);
  }

  Future<List<GroupSessionItem>> fetchSessions(String classId) async {
    final rows = await supabase
        .from('group_sessions_visible')
        .select('seq, scheduled_at')
        .eq('group_class_id', classId)
        .order('seq');
    return rows.map(GroupSessionItem.fromMap).toList();
  }

  Future<List<GroupSeatItem>> fetchMySeats() async {
    final rows = await supabase
        .from('group_seats')
        .select(
          'id, group_class_id, price_paid, status, refund_amount, lock_expires_at',
        )
        .order('created_at', ascending: false);
    return rows.map(GroupSeatItem.fromMap).toList();
  }

  Future<GroupSeatItem?> fetchMySeat(String classId) async {
    final row = await supabase
        .from('group_seats')
        .select(
          'id, group_class_id, price_paid, status, refund_amount, lock_expires_at',
        )
        .eq('group_class_id', classId)
        .neq('status', 'cancelled')
        .maybeSingle();
    return row == null ? null : GroupSeatItem.fromMap(row);
  }

  /// Beli kursi: ambil kursi (kunci) + transaksi Snap.
  Future<SnapResult> createSeatSnap({
    required String groupClassId,
    bool useCredits = false,
  }) async {
    final res = await supabase.functions.invoke(
      'create-group-seat-snap',
      body: {
        'group_class_id': groupClassId,
        if (useCredits) 'use_credits': true,
      },
    );
    final data = res.data;
    if (res.status != 200) {
      final msg = (data is Map && data['error'] != null)
          ? data['error'] as String
          : 'Gagal memulai pembayaran (${res.status})';
      throw Exception(msg);
    }
    return SnapResult.fromJson(data as Map<String, dynamic>);
  }
}
