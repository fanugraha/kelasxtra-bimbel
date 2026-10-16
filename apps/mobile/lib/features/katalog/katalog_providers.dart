import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'katalog_repository.dart';

final katalogRepositoryProvider =
    Provider<KatalogRepository>((ref) => KatalogRepository());

/// Filter katalog: mapel, jenjang, mode, dan rating minimum (semua opsional).
class KatalogFilter {
  const KatalogFilter({this.subjectId, this.jenjang, this.mode, this.minRating});
  final String? subjectId;
  final String? jenjang;
  final String? mode;
  final double? minRating;

  KatalogFilter copyWith({
    String? subjectId,
    String? jenjang,
    String? mode,
    double? minRating,
    bool clearMode = false,
    bool clearRating = false,
  }) =>
      KatalogFilter(
        subjectId: subjectId ?? this.subjectId,
        jenjang: jenjang ?? this.jenjang,
        mode: clearMode ? null : (mode ?? this.mode),
        minRating: clearRating ? null : (minRating ?? this.minRating),
      );
}

class KatalogFilterNotifier extends Notifier<KatalogFilter> {
  @override
  KatalogFilter build() => const KatalogFilter();

  void setSubject(String? id) => state = state.copyWith(subjectId: id);
  void setJenjang(String? jenjang) => state = state.copyWith(jenjang: jenjang);
  void setMode(String? mode) =>
      state = state.copyWith(mode: mode, clearMode: mode == null);
  void setMinRating(double? rating) =>
      state = state.copyWith(minRating: rating, clearRating: rating == null);
}

final katalogFilterProvider =
    NotifierProvider<KatalogFilterNotifier, KatalogFilter>(KatalogFilterNotifier.new);

/// Mapel aktif untuk dropdown filter.
final subjectsProvider = FutureProvider<List<SubjectOption>>(
  (ref) => ref.read(katalogRepositoryProvider).fetchSubjects(),
);

/// Daftar tutor aktif sesuai filter.
final tutorListProvider = FutureProvider<List<TutorCatalogItem>>((ref) {
  final f = ref.watch(katalogFilterProvider);
  return ref.read(katalogRepositoryProvider).fetchTutors(
        subjectId: f.subjectId,
        jenjang: f.jenjang,
        mode: f.mode,
        minRating: f.minRating,
      );
});

/// Detail tutor (profil + mapel + ketersediaan).
final tutorDetailProvider =
    FutureProvider.family<TutorDetail?, String>((ref, id) {
  return ref.read(katalogRepositoryProvider).fetchTutorDetail(id);
});
