import 'package:bimbel_mobile/features/katalog/katalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TutorCatalogItem.fromMap parsing', () {
    final t = TutorCatalogItem.fromMap({
      'id': 'abc',
      'full_name': 'Budi',
      'bio': null,
      'education': 'S1 Matematika',
      'photo_url': null,
      'rating_avg': 4.5,
    });
    expect(t.id, 'abc');
    expect(t.fullName, 'Budi');
    expect(t.education, 'S1 Matematika');
    expect(t.ratingAvg, 4.5);
    expect(t.photoUrl, isNull);
  });

  test('rating_avg null -> 0', () {
    final t = TutorCatalogItem.fromMap({'id': 'x', 'full_name': 'A'});
    expect(t.ratingAvg, 0);
    expect(t.education, isNull);
  });

  test('TutorAvailabilityItem day name + time range', () {
    const a = TutorAvailabilityItem(
      dayOfWeek: 1,
      startTime: '08:00:00',
      endTime: '10:30:00',
      mode: 'online',
    );
    expect(a.dayName, 'Senin');
    expect(a.timeRange, '08:00–10:30');
  });
}
