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
class TutorCatalogItem {
  const TutorCatalogItem({
    required this.id,
    required this.fullName,
    this.bio,
    this.education,
    this.photoUrl,
    required this.ratingAvg,
  });

  final String id;
  final String fullName;
  final String? bio;
  final String? education;
  final String? photoUrl;
  final double ratingAvg;

  factory TutorCatalogItem.fromMap(Map<String, dynamic> m) => TutorCatalogItem(
        id: m['id'] as String,
        fullName: (m['full_name'] ?? '') as String,
        bio: m['bio'] as String?,
        education: m['education'] as String?,
        photoUrl: m['photo_url'] as String?,
        ratingAvg: (m['rating_avg'] as num?)?.toDouble() ?? 0,
      );
}

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
  });

  final TutorCatalogItem tutor;
  final List<TutorSubjectItem> subjects;
  final List<TutorAvailabilityItem> availability;
}

class KatalogRepository {
  /// Daftar tutor aktif. Filter mapel/jenjang lewat `tutor_subjects`, mode lewat
  /// `tutor_availability`, rating lewat kolom `rating_avg`.
  Future<List<TutorCatalogItem>> fetchTutors({
    String? subjectId,
    String? jenjang,
    String? mode,
    double? minRating,
  }) async {
    Set<String>? ids;

    if (subjectId != null || jenjang != null) {
      var q = supabase.from('tutor_subjects').select('tutor_id');
      if (subjectId != null) q = q.eq('subject_id', subjectId);
      if (jenjang != null) q = q.eq('jenjang', jenjang);
      final rows = await q;
      ids = {for (final r in rows) r['tutor_id'] as String};
    }

    if (mode != null) {
      final rows = await supabase
          .from('tutor_availability')
          .select('tutor_id')
          .eq('mode', mode)
          .eq('active', true);
      final modeIds = {for (final r in rows) r['tutor_id'] as String};
      ids = ids == null ? modeIds : ids.intersection(modeIds);
    }

    if (ids != null && ids.isEmpty) return [];

    var query = supabase.from('tutor_catalog').select();
    if (ids != null) query = query.inFilter('id', ids.toList());
    if (minRating != null) query = query.gte('rating_avg', minRating);

    final data = await query.order('rating_avg', ascending: false);
    return data.map(TutorCatalogItem.fromMap).toList();
  }

  Future<List<SubjectOption>> fetchSubjects() async {
    final data =
        await supabase.from('subjects').select('id, name').eq('active', true).order('name');
    return data.map(SubjectOption.fromMap).toList();
  }

  Future<TutorDetail?> fetchTutorDetail(String id) async {
    final row = await supabase.from('tutor_catalog').select().eq('id', id).maybeSingle();
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
    );
  }
}
