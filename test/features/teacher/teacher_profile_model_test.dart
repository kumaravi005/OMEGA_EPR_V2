import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/data/models/gender.dart';
import 'package:omega_epr_v2/features/teacher/data/teacher_profile.dart';

void main() {
  test(
    'TeacherProfile round-trips through toMap/fromMap, including Set 12 fields',
    () {
      final teacher = TeacherProfile(
        uid: 'uid1',
        accountId: 'teacher1',
        name: 'Test Teacher',
        dateOfBirth: DateTime(1990, 3, 15),
        gender: Gender.female,
        photoUrl: 'https://example.com/photo.jpg',
        qualification: 'M.Sc. Physics',
        address: '456 Avenue',
        primaryMobile: '9876543210',
        secondaryMobile: null,
        subjectIds: const ['physics', 'chemistry'],
        active: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final restored = TeacherProfile.fromMap(teacher.uid, teacher.toMap());

      expect(restored.name, teacher.name);
      expect(restored.gender, Gender.female);
      expect(restored.photoUrl, 'https://example.com/photo.jpg');
      expect(restored.subjectIds, ['physics', 'chemistry']);
      expect(restored.active, isTrue);
    },
  );

  test(
    'supports multiple subjects for one teacher (not one subject per teacher)',
    () {
      final teacher = TeacherProfile(
        uid: 'uid2',
        accountId: 'teacher2',
        name: 'Multi Subject Teacher',
        dateOfBirth: DateTime(1985, 6, 1),
        gender: Gender.male,
        qualification: 'B.Ed.',
        address: '789 Road',
        primaryMobile: '9000000000',
        secondaryMobile: '9111111111',
        subjectIds: const ['hindi', 'social_science', 'science'],
        active: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(teacher.subjectIds.toSet(), {
        'hindi',
        'social_science',
        'science',
      });
    },
  );

  test(
    'fromMap defaults subjectIds to empty and active to true on a '
    'pre-Set-12 teacher document',
    () {
      final restored = TeacherProfile.fromMap('oldTeacher', {
        'accountId': 'teacher3',
        'name': 'Old Teacher',
        'dateOfBirth': Timestamp.fromDate(DateTime(1980, 1, 1)),
        'gender': 'male',
        'qualification': 'B.A.',
        'address': 'Address',
        'primaryMobile': '9999999999',
        'assignments': [
          {'className': 'Class 5', 'subject': 'Science'},
        ],
        'createdAt': Timestamp.fromDate(DateTime(2020, 1, 1)),
        'updatedAt': Timestamp.fromDate(DateTime(2020, 1, 1)),
      });

      expect(restored.subjectIds, isEmpty);
      expect(restored.active, isTrue);
      expect(restored.photoUrl, isNull);
    },
  );
}
