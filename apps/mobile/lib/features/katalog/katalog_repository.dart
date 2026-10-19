import '../../core/format.dart';
import '../../core/supabase_client.dart';

/// Pilihan mapel untuk filter katalog.
class SubjectOption {
  const SubjectOption({required this.id, required this.name});
  final String id;
  final String name;

  factory SubjectOption.fromMap(Map<String, dynamic> m) =>
      SubjectOption(id: m['id'] as String, name: m['name'] as String);
}

/// Baris katalog tutor (dari VIEW `tutor_catalog`, tanpa kolom bank).
///
/// Kolom ringkasan (`subjects`, `jenjang`, `days`, `modes`, `minPrice`) dipakai
/// kartu tutor di Beranda — semuanya dari view, jadi tidak perlu query tambahan.
class TutorCatalogItem {
  const TutorCatalogItem({
    required this.id,
    required this.fullName,
    this.bio,
    this.education,
    this.photoUrl,
    required this.ratingAvg,
    this.subjects,
    this.jenjang,
    this.days = const [],
    this.modes = const [],
    this.minPrice,
  });

  final String id;
  final String fullName;
  final String? bio;
  final String? education;
  final String? photoUrl;
  final double ratingAvg;
  final String? subjects;
  final String? jenjang;
  final List<int> days;
  final List<String> modes;
  final int? minPrice;

  /// "Fisika, Matematika · SMP, SMA" (bagian yang kosong dilewati).
  String get subjectLine => [
    if (subjects != null && subjects!.isNotEmpty) subjects!,
    if (jenjang != null && jenjang!.isNotEmpty) jenjang!,
  ].join(' · ');

  /// Hari tersedia sebagai label pendek, mis. ["Sen", "Rab", "Sab"].
  /// Minggu ditaruh paling akhir supaya urutannya enak dibaca.
  List<String> get dayLabels {
    final sorted = [...days]
      ..sort((a, b) => (a == 0 ? 7 : a).compareTo(b == 0 ? 7 : b));
    return [for (final d in sorted) AppFormat.shortDayName(d)];
  }

  factory TutorCatalogItem.fromMap(Map<String, dynamic> m) => TutorCatalogItem(
    id: m['id'] as String,
    fullName: (m['full_name'] ?? '') as String,
    bio: m['bio'] as String?,
    education: m['education'] as String?,
    photoUrl: m['photo_url'] as String?,
    ratingAvg: (m['rating_avg'] as num?)?.toDouble() ?? 0,
    subjects: m['subjects'] as String?,
    jenjang: m['jenjang'] as String?,
    days: _intList(m['days']),
    modes: _stringList(m['modes']),
    minPrice: (m['min_price'] as num?)?.toInt(),
  );
}

List<int> _intList(dynamic value) => value is List
    ? [
        for (final e in value)
          if (e is num) e.toInt(),
      ]
    : const [];

List<String> _stringList(dynamic value) => value is List
    ? [
        for (final e in value)
          if (e is String) e,
      ]
    : const [];

/// Mapel + jenjang yang diajar tutor.
class TutorSubjectItem {
  const TutorSubjectItem({
    required this.subjectId,
    required this.subjectName,
    required this.jenjang,
  });
  final String subjectId;
  final String subjectName;
  final String jenjang;
}

/// Slot ketersediaan mingguan tutor.
class TutorAvailabilityItem {
  const TutorAvailabilityItem({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.mode,
  });

  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final String mode;

  String get dayName => AppFormat.longDayName(dayOfWeek);
  String get timeRange => AppFormat.timeRange(startTime, endTime);
}

class TutorDetail {
  const TutorDetail({
    required this.tutor,
    required this.subjects,
    required this.availability,
    this.minPackagePrice,
    this.minPackageSesi,
  });

  final TutorCatalogItem tutor;
  final List<TutorSubjectItem> subjects;
  final List<TutorAvailabilityItem> availability;

  /// Harga paket termurah untuk kombinasi yang diajar tutor ini.
  final int? minPackagePrice;
  final int? minPackageSesi;
}

/// Satu ulasan siswa untuk tutor. Identitas siswa sengaja tidak dibawa
/// (data pribadi siswa lain), jadi ulasan tampil anonim.
class TutorReview {
  const TutorReview({
    required this.id,
    required this.rating,
    required this.createdAt,
    this.comment,
  });

  final String id;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  factory TutorReview.fromMap(Map<String, dynamic> m) => TutorReview(
    id: m['id'] as String,
    rating: (m['rating'] as num).toInt(),
    comment: m['comment'] as String?,
    createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
  );
}

/// Urutan hasil katalog. Dipakai tombol "Urutkan" di layar Cari Tutor.
enum KatalogSort {
  rating('Terbaik', 'Rating tertinggi lebih dulu'),
  price('Termurah', 'Harga sesi terendah lebih dulu'),
  name('A–Z', 'Nama tutor sesuai abjad');

  const KatalogSort(this.label, this.description);

  /// Label pendek untuk tombol.
  final String label;

  /// Penjelasan singkat di lembar "Urutkan".
  final String description;
}

class KatalogRepository {
  /// Daftar tutor aktif. Filter mapel/jenjang lewat `tutor_subjects`, mode/hari
  /// lewat `tutor_availability`, rating & urutan lewat `tutor_catalog`.
  Future<List<TutorCatalogItem>> fetchTutors({
    String? subjectId,
    String? jenjang,
    String? mode,
    Set<int> days = const {},
    double? minRating,
    KatalogSort sort = KatalogSort.rating,
  }) async {
    Set<String>? ids;

    if (subjectId != null || jenjang != null) {
      var q = supabase.from('tutor_subjects').select('tutor_id');
      if (subjectId != null) q = q.eq('subject_id', subjectId);
      if (jenjang != null) q = q.eq('jenjang', jenjang);
      final rows = await q;
      ids = {for (final r in rows) r['tutor_id'] as String};
    }

    if (mode != null || days.isNotEmpty) {
      var q = supabase
          .from('tutor_availability')
          .select('tutor_id')
          .eq('active', true);
      if (mode != null) q = q.eq('mode', mode);
      if (days.isNotEmpty) q = q.inFilter('day_of_week', days.toList());
      final rows = await q;
      final slotIds = {for (final r in rows) r['tutor_id'] as String};
      ids = ids == null ? slotIds : ids.intersection(slotIds);
    }

    if (ids != null && ids.isEmpty) return [];

    var query = supabase.from('tutor_catalog').select();
    if (ids != null) query = query.inFilter('id', ids.toList());
    if (minRating != null) query = query.gte('rating_avg', minRating);

    // Urutan kedua dipakai sebagai pemutus seri supaya daftar tidak berubah
    // posisi saat data diperbarui.
    final data = switch (sort) {
      KatalogSort.rating =>
        await query
            .order('rating_avg', ascending: false)
            .order('full_name', ascending: true),
      KatalogSort.price =>
        await query
            .order('min_price', ascending: true, nullsFirst: false)
            .order('rating_avg', ascending: false),
      KatalogSort.name =>
        await query
            .order('full_name', ascending: true)
            .order('rating_avg', ascending: false),
    };
    return data.map(TutorCatalogItem.fromMap).toList();
  }

  Future<List<SubjectOption>> fetchSubjects() async {
    final data = await supabase
        .from('subjects')
        .select('id, name')
        .eq('active', true)
        .order('name');
    return data.map(SubjectOption.fromMap).toList();
  }

  /// Ulasan terbaru untuk satu tutor (tabel `reviews` boleh dibaca publik).
  Future<List<TutorReview>> fetchTutorReviews(
    String tutorId, {
    int limit = 30,
  }) async {
    final rows = await supabase
        .from('reviews')
        .select('id, rating, comment, created_at')
        .eq('tutor_id', tutorId)
        .order('created_at', ascending: false)
        .limit(limit);
    return [for (final r in rows) TutorReview.fromMap(r)];
  }

  Future<TutorDetail?> fetchTutorDetail(String id) async {
    final row = await supabase
        .from('tutor_catalog')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;

    final subjectRows = await supabase
        .from('tutor_subjects')
        .select('subject_id, jenjang, subjects(name)')
        .eq('tutor_id', id);
    final availRows = await supabase
        .from('tutor_availability')
        .select('day_of_week, start_time, end_time, mode')
        .eq('tutor_id', id)
        .eq('active', true)
        .order('day_of_week');

    // Harga paket termurah (paket adalah satu-satunya cara memesan) di antara
    // kombinasi jenjang & mode yang diajar tutor ini.
    final jenjangs = {
      for (final r in subjectRows) r['jenjang'] as String,
    }.toList();
    final modeSet = {for (final r in availRows) r['mode'] as String}.toList();
    int? minPackagePrice;
    int? minPackageSesi;
    if (jenjangs.isNotEmpty && modeSet.isNotEmpty) {
      final priceRows = await supabase
          .from('package_prices')
          .select('price, total_sesi')
          .eq('active', true)
          .inFilter('jenjang', jenjangs)
          .inFilter('mode', modeSet);
      for (final r in priceRows) {
        final price = (r['price'] as num).toInt();
        if (minPackagePrice == null || price < minPackagePrice) {
          minPackagePrice = price;
          minPackageSesi = (r['total_sesi'] as num).toInt();
        }
      }
    }

    return TutorDetail(
      tutor: TutorCatalogItem.fromMap(row),
      subjects: [
        for (final r in subjectRows)
          TutorSubjectItem(
            subjectId: (r['subject_id'] ?? '') as String,
            subjectName: ((r['subjects'] as Map?)?['name'] ?? '-') as String,
            jenjang: (r['jenjang'] ?? '-') as String,
          ),
      ],
      availability: [
        for (final r in availRows)
          TutorAvailabilityItem(
            dayOfWeek: (r['day_of_week'] as num).toInt(),
            startTime: (r['start_time'] ?? '') as String,
            endTime: (r['end_time'] ?? '') as String,
            mode: (r['mode'] ?? '') as String,
          ),
      ],
      minPackagePrice: minPackagePrice,
      minPackageSesi: minPackageSesi,
    );
  }
}
