import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/features/teacher/data/teacher_profile.dart';

void main() {
  group('dedupeSubjectIds', () {
    test('removes duplicate subject ids, keeping first-occurrence order', () {
      expect(
        dedupeSubjectIds(['physics', 'chemistry', 'physics', 'biology']),
        ['physics', 'chemistry', 'biology'],
      );
    });

    test('a teacher can still be assigned several distinct subjects', () {
      expect(
        dedupeSubjectIds(['hindi', 'social_science', 'science']),
        ['hindi', 'social_science', 'science'],
      );
    });

    test('an empty list stays empty', () {
      expect(dedupeSubjectIds(const []), isEmpty);
    });
  });
}
