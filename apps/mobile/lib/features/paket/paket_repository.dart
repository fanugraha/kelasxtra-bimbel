import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/format.dart';
import '../../core/snap_result.dart';
import '../../core/supabase_client.dart';

/// Paket pertemuan milik siswa (4/8/12 pertemuan, seminggu sekali).
class PackageItem {
  const PackageItem({
    required this.id,
    required this.tutorId,
    required this.subjectId,
    required this.jenjang,
    required this.mode,
    required this.durationMinutes,
    required this.totalSesi,
    required this.priceTotal,
    required this.status,
    this.expiresAt,
    this.scheduleDay,
    this.scheduleStartTime,
    this.scheduleStartDate,
    this.tutorName,
    this.subjectName,
  });

  final String id;
  final String tutorId;
  final String subjectId;
  final String jenjang;
  final String mode;
  final int durationMinutes;
  final int totalSesi;
  final int priceTotal;
  final String status;
  final DateTime? expiresAt;

  /// Jadwal mingguan yang dipilih saat membeli (0 = Minggu).
  final int? scheduleDay;
  final String? scheduleStartTime;
  final DateTime? scheduleStartDate;

  final String? tutorName;
  final String? subjectName;

  bool get aktif => status == 'active';

  /// "Sabtu 09:00" — jadwal pertemuan tiap minggu.
  String get jadwalLabel {
    if (scheduleDay == null || scheduleStartTime == null) return '—';
    final jam = AppFormat.hhmm(AppFormat.minutesOfTime(scheduleStartTime!));
    return '${AppFormat.longDayName(scheduleDay!)}, $jam';
  }

  String get mulaiLabel =>
      scheduleStartDate == null ? '—' : AppFormat.dateLong(scheduleStartDate!);

  String get masaBerlakuLabel =>
      expiresAt == null ? '—' : AppFormat.dateLong(expiresAt!);

  String get statusLabel => switch (status) {
    'pending_payment' => 'Menunggu bayar',
    'active' => 'Aktif',
    'expired' => 'Kedaluwarsa',
    'refunded' => 'Dana dikembalikan',
    'cancelled' => 'Dibatalkan',
    _ => status,
  };

  factory PackageItem.fromMap(
    Map<String, dynamic> m, {
    String? tutorName,
    String? subjectName,
  }) => PackageItem(
    id: m['id'] as String,
    tutorId: m['tutor_id'] as String,
    subjectId: m['subject_id'] as String,
    jenjang: (m['jenjang'] ?? '-') as String,
    mode: (m['mode'] ?? '-') as String,
    durationMinutes: (m['duration_minutes'] as num).toInt(),
    totalSesi: (m['total_sesi'] as num).toInt(),
    priceTotal: (m['price_total'] as num).toInt(),
    status: (m['status'] ?? '-') as String,
    expiresAt: m['expires_at'] == null
        ? null
        : DateTime.parse(m['expires_at'] as String).toLocal(),
    scheduleDay: m['schedule_day'] == null
        ? null
        : (m['schedule_day'] as num).toInt(),
    scheduleStartTime: m['schedule_start_time'] as String?,
    scheduleStartDate: m['schedule_start_date'] == null
        ? null
        : DateTime.parse(m['schedule_start_date'] as String),
    tutorName: tutorName,
    subjectName: subjectName,
  );
}

/// Rentang waktu yang sudah terisi (dipakai menyaring pilihan jadwal).
class BusySlot {
  const BusySlot({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

class PaketRepository {
  static const _cols =
      'id, tutor_id, subject_id, jenjang, duration_minutes, mode, '
      'total_sesi, price_total, status, expires_at, schedule_day, '
      'schedule_start_time, schedule_start_date';

  /// Interval waktu yang sudah terisi (tutor & milik siswa) — untuk menyaring
  /// pilihan jadwal agar siswa tidak memilih slot yang bentrok.
  Future<List<BusySlot>> fetchBusySlots(String tutorId) async {
    final rows = await supabase.rpc(
      'tutor_busy_slots',
      params: {'p_tutor_id': tutorId},
    );
    return [
      for (final r in (rows as List))
        BusySlot(
          start: DateTime.parse((r as Map)['busy_start'] as String).toLocal(),
          end: DateTime.parse(r['busy_end'] as String).toLocal(),
        ),
    ];
  }

  Future<List<PackageItem>> fetchMyPackages() async {
    final rows = await supabase
        .from('package_purchases')
        .select(_cols)
        .order('created_at', ascending: false);
    return _withNames(rows);
  }

  /// Harga paket aktif (ditetapkan admin). Null bila kombinasi belum diset.
  Future<int?> fetchPackagePrice({
    required String jenjang,
    required int durationMinutes,
    required String mode,
    required int totalSesi,
  }) async {
    final row = await supabase
        .from('package_prices')
        .select('price')
        .eq('jenjang', jenjang)
        .eq('duration_minutes', durationMinutes)
        .eq('mode', mode)
        .eq('total_sesi', totalSesi)
        .eq('active', true)
        .maybeSingle();
    if (row == null) return null;
    return (row['price'] as num).toInt();
  }

  Future<List<PackageItem>> _withNames(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return [];
    final tutorIds = {for (final r in rows) r['tutor_id'] as String}.toList();
    final subjectIds = {
      for (final r in rows) r['subject_id'] as String,
    }.toList();

    final tutorRows = await supabase
        .from('tutor_catalog')
        .select('id, full_name')
        .inFilter('id', tutorIds);
    final subjectRows = await supabase
        .from('subjects')
        .select('id, name')
        .inFilter('id', subjectIds);

    final tutorNames = {
      for (final r in tutorRows)
        r['id'] as String: (r['full_name'] ?? '-') as String,
    };
    final subjectNames = {
      for (final r in subjectRows)
        r['id'] as String: (r['name'] ?? '-') as String,
    };

    return [
      for (final r in rows)
        PackageItem.fromMap(
          r,
          tutorName: tutorNames[r['tutor_id']],
          subjectName: subjectNames[r['subject_id']],
        ),
    ];
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

  /// Buat tagihan Snap untuk paket: pilih jumlah pertemuan + jadwal mingguan.
  Future<SnapResult> createPackageSnap({
    required String tutorId,
    required String subjectId,
    required String jenjang,
    required int durationMinutes,
    required String mode,
    required int totalSesi,
    required DateTime scheduleStartDate,
    required String scheduleStartTime,
    String? address,
    String? voucherCode,
    bool useCredits = false,
  }) {
    return _snap({
      'tutor_id': tutorId,
      'subject_id': subjectId,
      'jenjang': jenjang,
      'duration_minutes': durationMinutes,
      'mode': mode,
      'total_sesi': totalSesi,
      'schedule_start_date': _isoDate(scheduleStartDate),
      'schedule_start_time': scheduleStartTime,
      if (address != null && address.isNotEmpty) 'address': address,
      if (voucherCode != null && voucherCode.isNotEmpty)
        'voucher_code': voucherCode,
      if (useCredits) 'use_credits': true,
    });
  }

  /// Lanjutkan pembayaran paket yang masih menunggu bayar (jadwal tersimpan).
  Future<SnapResult> resumePackageSnap(String packageId) {
    return _snap({'resume_package_id': packageId});
  }

  Future<SnapResult> _snap(Map<String, dynamic> body) async {
    final res = await supabase.functions.invoke(
      'create-package-snap',
      body: body,
    );
    final data = res.data;
    if (res.status != 200) {
      final msg = (data is Map && data['error'] != null)
          ? data['error'] as String
          : 'Gagal memulai pembelian paket (${res.status})';
      throw Exception(msg);
    }
    return SnapResult.fromJson(data as Map<String, dynamic>);
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
