import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/data/models/gender.dart';
import 'package:omega_epr_v2/features/academics/data/school_class.dart';
import 'package:omega_epr_v2/features/academics/data/subject.dart';
import 'package:omega_epr_v2/features/teacher/data/teacher_profile.dart';
import 'package:omega_epr_v2/features/teacher_assignments/data/teacher_assignment.dart';
import 'package:omega_epr_v2/features/teacher_assignments/data/teacher_assignment_repository.dart';

TeacherAssignment _assignment({
  String teacherId = 't1',
  String academicSessionId = 's1',
  String classId = 'c1',
  String batchId = 'b1',
  String subjectId = 'math',
  bool active = true,
  String createdBy = 'admin1',
  String updatedBy = 'admin1',
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final id = TeacherAssignment.idFor(
    teacherId: teacherId,
    academicSessionId: academicSessionId,
    batchId: batchId,
    subjectId: subjectId,
  );
  return TeacherAssignment(
    assignmentId: id,
    teacherId: teacherId,
    academicSessionId: academicSessionId,
    classId: classId,
    batchId: batchId,
    subjectId: subjectId,
    active: active,
    createdBy: createdBy,
    updatedBy: updatedBy,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    updatedAt: updatedAt ?? DateTime(2026, 1, 1),
  );
}

TeacherProfile _teacher({
  String uid = 't1',
  List<String> subjectIds = const ['math', 'science'],
  bool active = true,
}) {
  return TeacherProfile(
    uid: uid,
    accountId: 'acc_$uid',
    name: 'Teacher $uid',
    dateOfBirth: DateTime(1990, 1, 1),
    gender: Gender.male,
    qualification: 'M.Sc.',
    address: 'Somewhere',
    primaryMobile: '9999999999',
    secondaryMobile: null,
    subjectIds: subjectIds,
    active: active,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

SchoolClass _schoolClass({
  String classId = 'c1',
  List<String> subjectIds = const ['math', 'science', 'hindi'],
}) {
  return SchoolClass(
    classId: classId,
    name: 'Class $classId',
    sortOrder: 1,
    active: true,
    subjectIds: subjectIds,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

Subject _subject(String id, {String? name}) {
  return Subject(
    subjectId: id,
    name: name ?? id,
    active: true,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('TeacherAssignment.idFor', () {
    test('is deterministic for the same teacher+session+batch+subject', () {
      final a = TeacherAssignment.idFor(
        teacherId: 't1',
        academicSessionId: 's1',
        batchId: 'b1',
        subjectId: 'math',
      );
      final b = TeacherAssignment.idFor(
        teacherId: 't1',
        academicSessionId: 's1',
        batchId: 'b1',
        subjectId: 'math',
      );
      expect(a, b);
    });

    test('differs when the subject differs (multiple subjects for one teacher)', () {
      final math = TeacherAssignment.idFor(
        teacherId: 't1',
        academicSessionId: 's1',
        batchId: 'b1',
        subjectId: 'math',
      );
      final science = TeacherAssignment.idFor(
        teacherId: 't1',
        academicSessionId: 's1',
        batchId: 'b1',
        subjectId: 'science',
      );
      expect(math, isNot(science));
    });

    test('differs when the batch differs (multiple batches for one teacher)', () {
      final batchA = TeacherAssignment.idFor(
        teacherId: 't1',
        academicSessionId: 's1',
        batchId: 'batchA',
        subjectId: 'math',
      );
      final batchB = TeacherAssignment.idFor(
        teacherId: 't1',
        academicSessionId: 's1',
        batchId: 'batchB',
        subjectId: 'math',
      );
      expect(batchA, isNot(batchB));
    });

    test('differs when the academic session differs', () {
      final year1 = TeacherAssignment.idFor(
        teacherId: 't1',
        academicSessionId: '2026-27',
        batchId: 'b1',
        subjectId: 'math',
      );
      final year2 = TeacherAssignment.idFor(
        teacherId: 't1',
        academicSessionId: '2027-28',
        batchId: 'b1',
        subjectId: 'math',
      );
      expect(year1, isNot(year2));
    });
  });

  group('TeacherAssignment serialization', () {
    test('round-trips through toMap/fromMap', () {
      final original = _assignment(active: false, updatedBy: 'admin2');
      final map = original.toMap();
      final restored = TeacherAssignment.fromMap(original.assignmentId, map);

      expect(restored.teacherId, original.teacherId);
      expect(restored.academicSessionId, original.academicSessionId);
      expect(restored.classId, original.classId);
      expect(restored.batchId, original.batchId);
      expect(restored.subjectId, original.subjectId);
      expect(restored.active, false);
      expect(restored.createdBy, original.createdBy);
      expect(restored.updatedBy, 'admin2');
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
    });

    test('a deactivated-then-reactivated assignment preserves createdAt/createdBy (historical integrity)', () {
      final createdAt = DateTime(2026, 1, 1);
      final deactivated = _assignment(
        active: false,
        createdBy: 'admin1',
        createdAt: createdAt,
        updatedBy: 'admin2',
        updatedAt: DateTime(2026, 6, 1),
      );
      // Simulate TeacherAssignmentController.setActive - only active/
      // updatedBy/updatedAt ever change.
      final map = Map<String, dynamic>.from(deactivated.toMap())
        ..['active'] = true
        ..['updatedBy'] = 'admin3'
        ..['updatedAt'] = Timestamp.fromDate(DateTime(2026, 7, 1));
      final reactivated = TeacherAssignment.fromMap(deactivated.assignmentId, map);

      expect(reactivated.active, true);
      expect(reactivated.createdAt, createdAt);
      expect(reactivated.createdBy, 'admin1');
    });
  });

  group('isDuplicateAssignment', () {
    test('detects an existing active assignment for the same combination', () {
      final existing = [_assignment()];
      expect(
        isDuplicateAssignment(
          existing,
          teacherId: 't1',
          academicSessionId: 's1',
          batchId: 'b1',
          subjectId: 'math',
        ),
        isTrue,
      );
    });

    test('detects an existing INACTIVE assignment for the same combination too', () {
      final existing = [_assignment(active: false)];
      expect(
        isDuplicateAssignment(
          existing,
          teacherId: 't1',
          academicSessionId: 's1',
          batchId: 'b1',
          subjectId: 'math',
        ),
        isTrue,
      );
    });

    test('is false for a different subject (same teacher/session/batch)', () {
      final existing = [_assignment(subjectId: 'math')];
      expect(
        isDuplicateAssignment(
          existing,
          teacherId: 't1',
          academicSessionId: 's1',
          batchId: 'b1',
          subjectId: 'science',
        ),
        isFalse,
      );
    });

    test('is false for a different batch (same teacher/session/subject)', () {
      final existing = [_assignment(batchId: 'b1')];
      expect(
        isDuplicateAssignment(
          existing,
          teacherId: 't1',
          academicSessionId: 's1',
          batchId: 'b2',
          subjectId: 'math',
        ),
        isFalse,
      );
    });

    test('is false for a different academic session (same teacher/batch/subject)', () {
      final existing = [_assignment(academicSessionId: '2026-27')];
      expect(
        isDuplicateAssignment(
          existing,
          teacherId: 't1',
          academicSessionId: '2027-28',
          batchId: 'b1',
          subjectId: 'math',
        ),
        isFalse,
      );
    });
  });

  group('subjectOptionsForAssignment (class-subject + teacher-capability restriction)', () {
    test('is empty until both a class and a teacher are selected', () {
      expect(
        subjectOptionsForAssignment(
          schoolClass: null,
          teacher: _teacher(),
          allSubjects: [_subject('math')],
        ),
        isEmpty,
      );
      expect(
        subjectOptionsForAssignment(
          schoolClass: _schoolClass(),
          teacher: null,
          allSubjects: [_subject('math')],
        ),
        isEmpty,
      );
    });

    test('only offers subjects the CLASS is configured with', () {
      final schoolClass = _schoolClass(subjectIds: ['math']);
      final teacher = _teacher(subjectIds: ['math', 'science', 'hindi']);
      final options = subjectOptionsForAssignment(
        schoolClass: schoolClass,
        teacher: teacher,
        allSubjects: [_subject('math'), _subject('science'), _subject('hindi')],
      );
      expect(options.map((s) => s.subjectId), ['math']);
    });

    test('only offers subjects the TEACHER is capable of teaching', () {
      final schoolClass = _schoolClass(subjectIds: ['math', 'science', 'hindi']);
      final teacher = _teacher(subjectIds: ['hindi']);
      final options = subjectOptionsForAssignment(
        schoolClass: schoolClass,
        teacher: teacher,
        allSubjects: [_subject('math'), _subject('science'), _subject('hindi')],
      );
      expect(options.map((s) => s.subjectId), ['hindi']);
    });

    test('is empty when the class and teacher share no subject', () {
      final schoolClass = _schoolClass(subjectIds: ['math']);
      final teacher = _teacher(subjectIds: ['hindi']);
      final options = subjectOptionsForAssignment(
        schoolClass: schoolClass,
        teacher: teacher,
        allSubjects: [_subject('math'), _subject('hindi')],
      );
      expect(options, isEmpty);
    });

    test('does not fall back to free text - class not offering the subject at all is excluded regardless of teacher capability', () {
      // A class-9-only teacher capability must never leak a class-5-only
      // subject into class 9's options (Set 22 section 20 example).
      final class9 = _schoolClass(classId: 'c9', subjectIds: ['math', 'physics']);
      final teacher = _teacher(subjectIds: ['math', 'class5OnlySubject']);
      final options = subjectOptionsForAssignment(
        schoolClass: class9,
        teacher: teacher,
        allSubjects: [_subject('math'), _subject('physics'), _subject('class5OnlySubject')],
      );
      expect(options.map((s) => s.subjectId), ['math']);
    });
  });

  group('assignmentsMatching (cascade / multi-dimensional filtering)', () {
    final all = [
      _assignment(teacherId: 'tA', batchId: 'b1', subjectId: 'hindi', academicSessionId: 's1'),
      _assignment(teacherId: 'tA', batchId: 'b2', subjectId: 'hindi', academicSessionId: 's1'),
      _assignment(teacherId: 'tA', batchId: 'b3', subjectId: 'science', academicSessionId: 's1'),
      _assignment(teacherId: 'tB', batchId: 'b4', subjectId: 'math', academicSessionId: 's1'),
      _assignment(teacherId: 'tB', batchId: 'b5', subjectId: 'math', academicSessionId: 's2'),
      _assignment(teacherId: 'tA', batchId: 'b6', subjectId: 'hindi', academicSessionId: 's1', active: false),
    ];

    test('one teacher can have multiple assignments (different batches/subjects)', () {
      final forTeacherA = assignmentsMatching(all, teacherId: 'tA');
      expect(forTeacherA.length, 4);
    });

    test('filters by teacher + subject (different subjects for one teacher)', () {
      final result = assignmentsMatching(all, teacherId: 'tA', subjectId: 'science');
      expect(result.length, 1);
      expect(result.single.batchId, 'b3');
    });

    test('filters by teacher + batch (different batches for one teacher)', () {
      final result = assignmentsMatching(all, teacherId: 'tA', batchId: 'b2');
      expect(result.length, 1);
      expect(result.single.subjectId, 'hindi');
    });

    test('filters by academic session (assignments are session-specific)', () {
      final resultS1 = assignmentsMatching(all, teacherId: 'tB', academicSessionId: 's1');
      final resultS2 = assignmentsMatching(all, teacherId: 'tB', academicSessionId: 's2');
      expect(resultS1.single.batchId, 'b4');
      expect(resultS2.single.batchId, 'b5');
    });

    test('active/inactive filter', () {
      final activeOnly = assignmentsMatching(all, teacherId: 'tA', active: true);
      final inactiveOnly = assignmentsMatching(all, teacherId: 'tA', active: false);
      expect(activeOnly.length, 3);
      expect(inactiveOnly.length, 1);
      expect(inactiveOnly.single.batchId, 'b6');
    });

    test('no filters returns everything', () {
      expect(assignmentsMatching(all).length, all.length);
    });
  });
}
