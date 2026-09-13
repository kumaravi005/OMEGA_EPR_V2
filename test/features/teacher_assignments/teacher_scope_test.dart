import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/features/teacher_assignments/data/teacher_assignment.dart';
import 'package:omega_epr_v2/features/teacher_assignments/data/teacher_assignment_repository.dart';

TeacherAssignment _assignment({
  String teacherId = 't1',
  String academicSessionId = 's1',
  String classId = 'c1',
  String batchId = 'b1',
  String subjectId = 'math',
  bool active = true,
}) {
  return TeacherAssignment(
    assignmentId: TeacherAssignment.idFor(
      teacherId: teacherId,
      academicSessionId: academicSessionId,
      batchId: batchId,
      subjectId: subjectId,
    ),
    teacherId: teacherId,
    academicSessionId: academicSessionId,
    classId: classId,
    batchId: batchId,
    subjectId: subjectId,
    active: active,
    createdBy: 'admin1',
    updatedBy: 'admin1',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('teacherCanOperateOn (Set 23 - assignment-derived authorization)', () {
    test('an active assignment grants scope for its exact session/batch/subject', () {
      final assignments = [_assignment()];
      expect(
        teacherCanOperateOn(
          assignments,
          academicSessionId: 's1',
          batchId: 'b1',
          subjectId: 'math',
        ),
        isTrue,
      );
    });

    test('an inactive assignment grants no operational scope', () {
      final assignments = [_assignment(active: false)];
      expect(
        teacherCanOperateOn(
          assignments,
          academicSessionId: 's1',
          batchId: 'b1',
          subjectId: 'math',
        ),
        isFalse,
      );
    });

    test('does not grant scope for a different batch', () {
      final assignments = [_assignment(batchId: 'b1')];
      expect(
        teacherCanOperateOn(
          assignments,
          academicSessionId: 's1',
          batchId: 'b2',
          subjectId: 'math',
        ),
        isFalse,
      );
    });

    test('does not grant scope for a different subject when the module is subject-specific', () {
      final assignments = [_assignment(subjectId: 'math')];
      expect(
        teacherCanOperateOn(
          assignments,
          academicSessionId: 's1',
          batchId: 'b1',
          subjectId: 'science',
        ),
        isFalse,
      );
    });

    test('does not grant scope for a different academic session', () {
      final assignments = [_assignment(academicSessionId: '2026-27')];
      expect(
        teacherCanOperateOn(
          assignments,
          academicSessionId: '2027-28',
          batchId: 'b1',
          subjectId: 'math',
        ),
        isFalse,
      );
    });

    test('ignores subject when the module is not subject-specific (attendance)', () {
      final assignments = [_assignment(subjectId: 'math')];
      // Attendance passes subjectId: null - any subject-assignment to
      // this session/batch is sufficient (Set 23 section 4).
      expect(
        teacherCanOperateOn(
          assignments,
          academicSessionId: 's1',
          batchId: 'b1',
        ),
        isTrue,
      );
    });

    test('multiple assignments work independently - each grants only its own scope', () {
      final assignments = [
        _assignment(classId: 'c8', batchId: 'batchA', subjectId: 'science'),
        _assignment(classId: 'c9', batchId: 'batchB', subjectId: 'mathematics'),
        _assignment(classId: 'c10', batchId: 'batchC', subjectId: 'mathematics'),
      ];

      expect(
        teacherCanOperateOn(
          assignments,
          academicSessionId: 's1',
          batchId: 'batchA',
          subjectId: 'science',
        ),
        isTrue,
      );
      expect(
        teacherCanOperateOn(
          assignments,
          academicSessionId: 's1',
          batchId: 'batchB',
          subjectId: 'mathematics',
        ),
        isTrue,
      );
      expect(
        teacherCanOperateOn(
          assignments,
          academicSessionId: 's1',
          batchId: 'batchC',
          subjectId: 'mathematics',
        ),
        isTrue,
      );
      // No assignment covers batchA + mathematics (only science there).
      expect(
        teacherCanOperateOn(
          assignments,
          academicSessionId: 's1',
          batchId: 'batchA',
          subjectId: 'mathematics',
        ),
        isFalse,
      );
    });

    test('a client cannot bypass scope by claiming a different subject/batch/session for the same list of assignments', () {
      // Simulates "do not trust IDs supplied by the client alone" (Set
      // 23 section 2) - the assignment list is the source of truth
      // regardless of what a caller claims it wants to operate on.
      final assignments = [_assignment(subjectId: 'hindi', batchId: 'homeroom')];
      for (final attempt in [
        (batchId: 'otherBatch', subjectId: 'hindi'),
        (batchId: 'homeroom', subjectId: 'english'),
      ]) {
        expect(
          teacherCanOperateOn(
            assignments,
            academicSessionId: 's1',
            batchId: attempt.batchId,
            subjectId: attempt.subjectId,
          ),
          isFalse,
        );
      }
    });
  });

  group('distinctActiveBatchScopes (Set 23 section 5 - dedup batch choices)', () {
    test('collapses two subject-assignments to the same batch into one entry', () {
      final assignments = [
        _assignment(batchId: 'b1', subjectId: 'math'),
        _assignment(batchId: 'b1', subjectId: 'science'),
      ];
      final scopes = distinctActiveBatchScopes(assignments);
      expect(scopes.length, 1);
      expect(scopes.single.batchId, 'b1');
    });

    test('keeps distinct batches separate', () {
      final assignments = [
        _assignment(batchId: 'b1'),
        _assignment(batchId: 'b2'),
      ];
      expect(distinctActiveBatchScopes(assignments).length, 2);
    });

    test('the same batch in two different sessions counts as two scopes', () {
      final assignments = [
        _assignment(academicSessionId: '2026-27', batchId: 'b1'),
        _assignment(academicSessionId: '2027-28', batchId: 'b1'),
      ];
      expect(distinctActiveBatchScopes(assignments).length, 2);
    });

    test('excludes inactive assignments entirely', () {
      final assignments = [
        _assignment(batchId: 'b1', active: true),
        _assignment(batchId: 'b2', active: false),
      ];
      final scopes = distinctActiveBatchScopes(assignments);
      expect(scopes.length, 1);
      expect(scopes.single.batchId, 'b1');
    });
  });

  group('capability vs assignment stay separate (Set 23 section 1)', () {
    test('having no assignment for a batch/subject grants no operational scope, regardless of capability', () {
      // TeacherProfile.subjectIds is not consulted by teacherCanOperateOn
      // at all - it takes only a list of TeacherAssignment. An empty
      // assignment list (e.g. a teacher whose profile lists Mathematics/
      // Science/Hindi as capability, but who has never been assigned to
      // any batch) must grant zero operational scope.
      const noAssignments = <TeacherAssignment>[];
      expect(
        teacherCanOperateOn(
          noAssignments,
          academicSessionId: 's1',
          batchId: 'b1',
          subjectId: 'math',
        ),
        isFalse,
      );
    });
  });
}
