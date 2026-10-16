import '../../core/snap_result.dart';
import '../../core/supabase_client.dart';

/// Paket sesi milik siswa.
class PackageItem {
  const PackageItem({
    required this.id,
    required this.tutorId,
    required this.subjectId,
    required this.jenjang,
    required this.mode,
    required this.durationMinutes,
    required this.totalSesi,
    required this.sesiTerpakai,
    required this.pricePerSession,
    required this.discountPercent,
    required this.priceTotal,
    required this.status,
    this.expiresAt,
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
  final int sesiTerpakai;
  final int pricePerSession;
  final int discountPercent;
  final int priceTotal;
  final String status;
  final DateTime? expiresAt;
  final String? tutorName;
  final String? subjectName;

  int get sisaSesi => totalSesi - sesiTerpakai;
  bool get aktif => status == 'active' && sisaSesi > 0;

  String get statusLabel => switch (status) {
        'pending_payment' => 'Menunggu bayar',
        'active' => sisaSesi > 0 ? 'Aktif' : 'Kuota habis',
        'expired' => 'Kedaluwarsa',
        'refunded' => 'Dana dikembalikan',
        'cancelled' => 'Dibatalkan',
        _ => status,
      };

  factory PackageItem.fromMap(
    Map<String, dynamic> m, {
    String? tutorName,
    String? subjectName,
  }) =>
      PackageItem(
        id: m['id'] as String,
        tutorId: m['tutor_id'] as String,
        subjectId: m['subject_id'] as String,
        jenjang: (m['jenjang'] ?? '-') as String,
        mode: (m['mode'] ?? '-') as String,
        durationMinutes: (m['duration_minutes'] as num).toInt(),
        totalSesi: (m['total_sesi'] as num).toInt(),
        sesiTerpakai: (m['sesi_terpakai'] as num).toInt(),
        pricePerSession: (m['price_per_session'] as num).toInt(),
        discountPercent: (m['discount_percent'] as num).toInt(),
        priceTotal: (m['price_total'] as num).toInt(),
        status: (m['status'] ?? '-') as String,
        expiresAt: m['expires_at'] == null
            ? null
            : DateTime.parse(m['expires_at'] as String).toLocal(),
        tutorName: tutorName,
        subjectName: subjectName,
      );
}

class PaketRepository {
  static const _cols = 'id, tutor_id, subject_id, jenjang, duration_minutes, mode, '
      'total_sesi, sesi_terpakai, price_per_session, discount_percent, '
      'price_total, status, expires_at';

  Future<List<PackageItem>> fetchMyPackages() async {
    final rows = await supabase
        .from('package_purchases')
        .select(_cols)
        .order('created_at', ascending: false);
    return _withNames(rows);
  }

  /// Paket aktif untuk tutor tertentu (dipakai saat booking pakai kuota).
  Future<List<PackageItem>> fetchActiveForTutor(String tutorId) async {
    final rows = await supabase
        .from('package_purchases')
        .select(_cols)
        .eq('tutor_id', tutorId)
        .eq('status', 'active')
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at', ascending: false);
    return _withNames(rows);
  }

  Future<List<PackageItem>> _withNames(List<Map<String, dynamic>> rows) async {
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
        PackageItem.fromMap(
          r,
          tutorName: tutorNames[r['tutor_id']],
          subjectName: subjectNames[r['subject_id']],
        ),
    ];
  }

  /// Buat transaksi Snap untuk pembelian paket.
  Future<SnapResult> createPackageSnap({
    required String tutorId,
    required String subjectId,
    required String jenjang,
    required int durationMinutes,
    required String mode,
    required int totalSesi,
  }) async {
    final res = await supabase.functions.invoke(
      'create-package-snap',
      body: {
        'tutor_id': tutorId,
        'subject_id': subjectId,
        'jenjang': jenjang,
        'duration_minutes': durationMinutes,
        'mode': mode,
        'total_sesi': totalSesi,
      },
    );
    final data = res.data;
    if (res.status != 200) {
      final msg = (data is Map && data['error'] != null)
          ? data['error'] as String
          : 'Gagal memulai pembelian paket (${res.status})';
      throw Exception(msg);
    }
    final map = data as Map<String, dynamic>;
    return SnapResult(
      orderId: map['order_id'] as String,
      packageId: map['package_id'] as String?,
      redirectUrl: map['redirect_url'] as String,
      amount: (map['amount'] as num).toInt(),
      reused: (map['reused'] ?? false) as bool,
    );
  }

  /// Booking yang dibayar dengan kuota paket (tanpa pembayaran per sesi).
  Future<int> bookWithPackage({
    required String packageId,
    required DateTime scheduledAt,
    String? address,
  }) async {
    final res = await supabase.functions.invoke(
      'book-with-package',
      body: {
        'package_id': packageId,
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        if (address != null && address.isNotEmpty) 'address': address,
      },
    );
    final data = res.data;
    if (res.status != 200) {
      final msg = (data is Map && data['error'] != null)
          ? data['error'] as String
          : 'Gagal memakai kuota paket (${res.status})';
      throw Exception(msg);
    }
    return ((data as Map)['sesi_terpakai'] as num).toInt();
  }
}
