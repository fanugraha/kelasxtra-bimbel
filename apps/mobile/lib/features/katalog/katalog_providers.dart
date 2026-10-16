import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'katalog_repository.dart';

final katalogRepositoryProvider =
    Provider<KatalogRepository>((ref) => KatalogRepository());

/// Filter katalog: mapel (opsional) + jenjang (opsional).
class KatalogFilter {
  const KatalogFilter({this.subjectId, this.jenjang});
  final String? subjectId;
  final String? jenjang;
}

class KatalogFilterNotifier extends Notifier<KatalogFilter> {
  @override
  KatalogFilter build() => const KatalogFilter();

  void setSubject(String? id) =>
      state = KatalogFilter(subjectId: id, jenjang: state.jenjang);
  void setJenjang(String? jenjang) =>
      state = KatalogFilter(subjectId: state.subjectId, jenjang: jenjang);
  void reset() => state = const KatalogFilter();
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
  return ref
      .read(katalogRepositoryProvider)
      .fetchTutors(subjectId: f.subjectId, jenjang: f.jenjang);
});

/// Detail tutor (profil + mapel + ketersediaan).
final tutorDetailProvider =
    FutureProvider.family<TutorDetail?, String>((ref, id) {
  return ref.read(katalogRepositoryProvider).fetchTutorDetail(id);
});
