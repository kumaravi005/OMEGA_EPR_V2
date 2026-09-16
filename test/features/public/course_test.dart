import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/features/public/data/course.dart';

Course _course({int sortOrder = 0, bool active = true}) {
  final now = DateTime(2026, 4, 1);
  return Course(
    courseId: 'course1',
    title: 'Class 9 (BSEB)',
    description: 'Board exam preparation',
    imageUrl: 'https://example.com/course.jpg',
    active: active,
    sortOrder: sortOrder,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('Course (Our courses row)', () {
    test('round-trips through toMap/fromMap, including sortOrder', () {
      final course = _course(sortOrder: 2);
      final restored = Course.fromMap(course.courseId, course.toMap());

      expect(restored.sortOrder, 2);
      expect(restored.title, course.title);
      expect(restored.description, course.description);
      expect(restored.imageUrl, course.imageUrl);
      expect(restored.active, isTrue);
    });

    test(
      'fromMap defaults sortOrder to 0 when the field is missing',
      () {
        final course = _course();
        final map = course.toMap()..remove('sortOrder');
        final restored = Course.fromMap(course.courseId, map);

        expect(restored.sortOrder, 0);
      },
    );

    test('fromMap tolerates a null imageUrl and description', () {
      final map = _course().toMap()
        ..['imageUrl'] = null
        ..['description'] = null;
      final restored = Course.fromMap('course1', map);

      expect(restored.imageUrl, isNull);
      expect(restored.description, isNull);
    });
  });
}
