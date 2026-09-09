import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/data/models/gender.dart';
import 'package:omega_epr_v2/features/teacher/data/teacher_profile.dart';

void main() {
  test('TeacherProfile round-trips through toMap/fromMap, including assignments', () {
    final teacher = TeacherProfile(
      uid: 'uid1',
      accountId: 'teacher1',
      name: 'Test Teacher',
      dateOfBirth: DateTime(1990, 3, 15),
      gender: Gender.female,
      qualification: 'M.Sc. Physics',
      address: '456 Avenue',
      primaryMobile: '9876543210',
      secondaryMobile: null,
      assignments: const [
        ClassSubjectAssignment(className: 'Class 5', subject: 'Science'),
        ClassSubjectAssignment(className: 'Class 7', subject: 'Hindi'),
      ],
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final restored = TeacherProfile.fromMap(teacher.uid, teacher.toMap());

    expect(restored.name, teacher.name);
    expect(restored.gender, Gender.female);
    expect(restored.assignments.length, 2);
    expect(restored.assignments[0].className, 'Class 5');
    expect(restored.assignments[0].subject, 'Science');
    expect(restored.assignments[1].className, 'Class 7');
    expect(restored.assignments[1].subject, 'Hindi');
  });

  test('supports multiple classes and subjects for one teacher (not one subject per teacher)', () {
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
      assignments: const [
        ClassSubjectAssignment(className: 'Class 5', subject: 'Science'),
        ClassSubjectAssignment(className: 'Class 6', subject: 'Science'),
        ClassSubjectAssignment(className: 'Class 7', subject: 'Hindi'),
      ],
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    expect(teacher.assignments.map((a) => a.subject).toSet(), {'Science', 'Hindi'});
    expect(teacher.assignments.map((a) => a.className).toSet(), {'Class 5', 'Class 6', 'Class 7'});
  });
}
