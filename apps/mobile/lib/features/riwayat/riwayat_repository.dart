import '../../core/format.dart';
import '../../core/supabase_client.dart';

/// Jenis transaksi yang dibayar siswa.
enum TransaksiKind { paket, sesi, langganan, kelasGrup }

/// Satu baris riwayat transaksi (uang), bukan agenda sesi.
class TransaksiItem {
  const TransaksiItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.status,
    required this.at,
    this.note,
    this.route,
  });

  final String id;
  final TransaksiKind kind;
  final String title;
  final String subtitle;
  final int amount;
  final String status;
  final DateTime at;
  final String? note;

  /// Halaman yang dibuka saat baris ditekan (null = tidak ada aksi).
  final String? route;
}

/// Riwayat transaksi siswa dari empat sumber yang bisa dibaca client:
/// paket pertemuan, sesi satuan (legacy), langganan bank soal, kursi kelas grup.
///
/// Catatan: `payments` untuk paket tidak terbuka untuk siswa (booking kosong),
/// jadi pembelian paket dibaca dari `package_purchases`.
class RiwayatRepository {
  Future<List<TransaksiItem>> fetchRiwayat() async {
    final results = await Future.wait([
      _paket(),
      _sesi(),
      _langganan(),
      _kelasGrup(),
    ]);
    final all = results.expand((rows) => rows).toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    return all;
  }

  Future<List<TransaksiItem>> _paket() async {
    final rows = await supabase
        .from('package_purchases')
        .select('id, tutor_id, subject_id, total_sesi, jenjang, price_total, '
            'discount, status, created_at, purchased_at')
        .order('created_at', ascending: false);
    if (rows.isEmpty) return [];

    final tutorIds = {for (final r in rows) r['tutor_id'] as String}.toList();
    final subjectIds = {for (final r in rows) r['subject_id'] as String}.toList();
    final tutorNames = await _names('tutor_catalog', 'full_name', tutorIds);
    final subjectNames = await _names('subjects', 'name', subjectIds);

    return [
      for (final r in rows)
        TransaksiItem(
          id: r['id'] as String,
          kind: TransaksiKind.paket,
          title: 'Paket ${r['total_sesi']} pertemuan',
          subtitle: '${subjectNames[r['subject_id']] ?? '-'} · '
              '${tutorNames[r['tutor_id']] ?? '-'} · ${r['jenjang'] ?? '-'}',
          amount: (r['price_total'] as num).toInt() -
              ((r['discount'] as num?)?.toInt() ?? 0),
          status: (r['status'] ?? '-') as String,
          at: _date(r['purchased_at'] ?? r['created_at']),
          note: ((r['discount'] as num?)?.toInt() ?? 0) > 0
              ? 'Sudah termasuk diskon voucher'
              : null,
          route: '/paket',
        ),
    ];
  }

  Future<List<TransaksiItem>> _sesi() async {
    final pays = await supabase
        .from('payments')
        .select('order_id, amount, status, paid_at, created_at, booking_id')
        .not('booking_id', 'is', null)
        .order('created_at', ascending: false);
    if (pays.isEmpty) return [];

    final bookingIds = {
      for (final p in pays)
        if (p['booking_id'] != null) p['booking_id'] as String,
    }.toList();
    final bookings = await supabase
        .from('bookings_visible')
        .select('id, subject_id, tutor_id, duration_minutes')
        .inFilter('id', bookingIds);
    final byId = {for (final b in bookings) b['id'] as String: b};

    final subjectNames = await _names('subjects', 'name', [
      for (final b in bookings) b['subject_id'] as String,
    ]);
    final tutorNames = await _names('tutor_catalog', 'full_name', [
      for (final b in bookings) b['tutor_id'] as String,
    ]);

    return [
      for (final p in pays)
        if (byId[p['booking_id']] case final b?)
          TransaksiItem(
            id: p['order_id'] as String,
            kind: TransaksiKind.sesi,
            title: 'Sesi ${b['duration_minutes'] ?? '-'} menit',
            subtitle: '${subjectNames[b['subject_id']] ?? '-'} · '
                '${tutorNames[b['tutor_id']] ?? '-'}',
            amount: (p['amount'] as num).toInt(),
            status: (p['status'] ?? '-') as String,
            at: _date(p['paid_at'] ?? p['created_at']),
            note: 'ID ${(p['order_id'] as String).split('-').last.toUpperCase()}',
            route: '/sesi/${p['booking_id']}',
          ),
    ];
  }

  Future<List<TransaksiItem>> _langganan() async {
    final rows = await supabase
        .from('subscriptions')
        .select('id, plan_code, status, current_period_end, created_at')
        .order('created_at', ascending: false);
    if (rows.isEmpty) return [];

    final plans = await supabase
        .from('subscription_plans')
        .select('code, name, price');
    final byCode = {for (final p in plans) p['code'] as String: p};

    return [
      for (final r in rows)
        TransaksiItem(
          id: r['id'] as String,
          kind: TransaksiKind.langganan,
          title: 'Langganan ${byCode[r['plan_code']]?['name'] ?? 'bank soal'}',
          subtitle: r['current_period_end'] == null
              ? 'Aktif bulanan, diperpanjang otomatis'
              : 'Berlaku sampai ${AppFormat.dateLong(_date(r['current_period_end']))}',
          amount: ((byCode[r['plan_code']]?['price'] as num?) ?? 0).toInt(),
          status: (r['status'] ?? '-') as String,
          at: _date(r['created_at']),
          route: '/bank-soal',
        ),
    ];
  }

  Future<List<TransaksiItem>> _kelasGrup() async {
    final seats = await supabase
        .from('group_seats')
        .select('id, group_class_id, price_paid, status, refund_amount, created_at')
        .order('created_at', ascending: false);
    if (seats.isEmpty) return [];

    final classIds = {for (final s in seats) s['group_class_id'] as String}.toList();
    final classes = await supabase
        .from('group_classes_visible')
        .select('id, subject_name, tutor_name, jenjang, total_sesi')
        .inFilter('id', classIds);
    final byId = {for (final c in classes) c['id'] as String: c};

    return [
      for (final s in seats)
        if (byId[s['group_class_id']] case final c?)
          TransaksiItem(
            id: s['id'] as String,
            kind: TransaksiKind.kelasGrup,
            title: 'Kelas grup ${c['subject_name'] ?? ''}'.trim(),
            subtitle: '${c['tutor_name'] ?? '-'} · ${c['jenjang'] ?? '-'} · '
                '${c['total_sesi'] ?? '-'} sesi',
            amount: (s['price_paid'] as num).toInt(),
            status: (s['status'] ?? '-') as String,
            at: _date(s['created_at']),
            note: ((s['refund_amount'] as num?)?.toInt() ?? 0) > 0
                ? 'Dana kembali sebagian'
                : null,
            route: '/kelas-grup/${s['group_class_id']}',
          ),
    ];
  }

  Future<Map<String, String>> _names(
    String table,
    String column,
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const {};
    final rows = await supabase.from(table).select('id, $column').inFilter('id', ids);
    return {
      for (final r in rows) r['id'] as String: (r[column] ?? '-') as String,
    };
  }

  DateTime _date(Object? value) => DateTime.parse(value as String).toLocal();
}
