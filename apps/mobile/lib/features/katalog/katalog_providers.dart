import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'katalog_repository.dart';

final katalogRepositoryProvider = Provider<KatalogRepository>(
  (ref) => KatalogRepository(),
);

/// Filter katalog: mapel, jenjang, mode, hari tersedia, dan rating minimum.
///
/// Hari boleh lebih dari satu ("aku bisa Sen dan Rab"); sisanya satu pilihan
/// supaya lembar filter tetap ringkas.
class KatalogFilter {
  const KatalogFilter({
    this.subjectId,
    this.jenjang,
    this.mode,
    this.days = const {},
    this.minRating,
    this.sort = KatalogSort.rating,
  });

  final String? subjectId;
  final String? jenjang;
  final String? mode;
  final Set<int> days;
  final double? minRating;
  final KatalogSort sort;

  /// Jumlah pilihan filter yang aktif — dipakai lencana tombol "Filter".
  int get activeCount =>
      (subjectId == null ? 0 : 1) +
      (jenjang == null ? 0 : 1) +
      (mode == null ? 0 : 1) +
      days.length +
      (minRating == null ? 0 : 1);

  bool get isFiltered => activeCount > 0;

  KatalogFilter copyWith({
    String? subjectId,
    String? jenjang,
    String? mode,
    Set<int>? days,
    double? minRating,
    KatalogSort? sort,
    bool clearSubject = false,
    bool clearJenjang = false,
    bool clearMode = false,
    bool clearRating = false,
  }) => KatalogFilter(
    subjectId: clearSubject ? null : (subjectId ?? this.subjectId),
    jenjang: clearJenjang ? null : (jenjang ?? this.jenjang),
    mode: clearMode ? null : (mode ?? this.mode),
    days: days ?? this.days,
    minRating: clearRating ? null : (minRating ?? this.minRating),
    sort: sort ?? this.sort,
  );
}

class KatalogFilterNotifier extends Notifier<KatalogFilter> {
  @override
  KatalogFilter build() => const KatalogFilter();

  void setSubject(String? id) =>
      state = state.copyWith(subjectId: id, clearSubject: id == null);
  void setJenjang(String? jenjang) =>
      state = state.copyWith(jenjang: jenjang, clearJenjang: jenjang == null);
  void setMode(String? mode) =>
      state = state.copyWith(mode: mode, clearMode: mode == null);
  void setMinRating(double? rating) =>
      state = state.copyWith(minRating: rating, clearRating: rating == null);
  void setSort(KatalogSort sort) => state = state.copyWith(sort: sort);

  void toggleDay(int day) {
    final days = {...state.days};
    if (!days.remove(day)) days.add(day);
    state = state.copyWith(days: days);
  }

  /// Bersihkan semua filter, urutan tetap seperti pilihan pengguna.
  void reset() => state = KatalogFilter(sort: state.sort);
}

final katalogFilterProvider =
    NotifierProvider<KatalogFilterNotifier, KatalogFilter>(
      KatalogFilterNotifier.new,
    );

/// Mapel aktif untuk dropdown filter.
final subjectsProvider = FutureProvider<List<SubjectOption>>(
  (ref) => ref.read(katalogRepositoryProvider).fetchSubjects(),
);

/// Daftar tutor aktif sesuai filter.
final tutorListProvider = FutureProvider<List<TutorCatalogItem>>((ref) {
  final f = ref.watch(katalogFilterProvider);
  return ref
      .read(katalogRepositoryProvider)
      .fetchTutors(
        subjectId: f.subjectId,
        jenjang: f.jenjang,
        mode: f.mode,
        days: f.days,
        minRating: f.minRating,
        sort: f.sort,
      );
});

/// Tutor pilihan di Beranda — tidak ikut filter katalog.
final featuredTutorsProvider = FutureProvider<List<TutorCatalogItem>>(
  (ref) => ref.read(katalogRepositoryProvider).fetchTutors(),
);

/// Detail tutor (profil + mapel + ketersediaan).
final tutorDetailProvider = FutureProvider.family<TutorDetail?, String>((
  ref,
  id,
) {
  return ref.read(katalogRepositoryProvider).fetchTutorDetail(id);
});

/// Ulasan terbaru seorang tutor (tab Ulasan di profil).
final tutorReviewsProvider = FutureProvider.family<List<TutorReview>, String>(
  (ref, id) => ref.read(katalogRepositoryProvider).fetchTutorReviews(id),
);
