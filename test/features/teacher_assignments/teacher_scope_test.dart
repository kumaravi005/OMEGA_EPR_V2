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
    test('an active assignment grants scope for its exact session/class/batch/subject', () {
      final assignments = [_assignment()];
      expect(
        teacherCanOperateOn(
          assignments,
          academicSessionId: 's1',
          classId: 'c1',
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
          classId: 'c1',
          batchId: 'b1',
          subjectId: 'math',
        ),
        isFalse,
      );
    });

    test('does not grant scope for a different batch (client-manipulated batchId)', () {
      final assignments = [_assignment(batchId: 'b1')];
      expect(
        teacherCanOperateOn(
          assignments,
          academicSessionId: 's1',
          classId: 'c1',
          batchId: 'b2',
          subjectId: 'math',
        ),
        isFalse,
      );
    });

    test('does not grant scope for a different class (client-manipulated classId)', () {
      // Set 24 hardening: teacherCanOperateOn previously did not check
      // classId at all, which could show a manage/edit action the
      // firestore.rules `teacherIsAssignedTo` check would then reject -
      // a batch's own classId can be edited after an assignment was
      // created (BatchController.updateBatch), so the assignment must
      // keep authorizing only the class it was actually created for.
      final assignments = [_assignment(classId: 'c9')];
      expect(
        teacherCanOperateOn(
          assignments,
          academicSessionId: 's1',
          classId: 'c10',
          batchId: 'b1',
          subjectId: 'math',
        ),
        isFalse,
      );
    });

    test('does not grant scope for a different subject when the module is subject-specific (client-manipulated subjectId)', () {
      final assignments = [_assignment(subjectId: 'math')];
      expect(
        teacherCanOperateOn(
          assignments,
          academicSessionId: 's1',
          classId: 'c1',
          batchId: 'b1',
          subjectId: 'science',
        ),
        isFalse,
      );
    });

    test('does not grant scope for a different academic session (client-manipulated sessionId)', () {
      final assignments = [_assignment(academicSessionId: '2026-27')];
      expect(
        teacherCanOperateOn(
          assignments,
          academicSessionId: '2027-28',
          classId: 'c1',
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
          classId: 'c1',
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
          classId: 'c8',
          batchId: 'batchA',
          subjectId: 'science',
        ),
        isTrue,
      );
      expect(
        teacherCanOperateOn(
          assignments,
          academicSessionId: 's1',
          classId: 'c9',
          batchId: 'batchB',
          subjectId: 'mathematics',
        ),
        isTrue,
      );
      expect(
        teacherCanOperateOn(
          assignments,
          academicSessionId: 's1',
          classId: 'c10',
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
          classId: 'c8',
          batchId: 'batchA',
          subjectId: 'mathematics',
        ),
        isFalse,
      );
    });

    test('a client cannot bypass scope by claiming a different subject/batch/session/class for the same list of assignments', () {
      // Simulates "do not trust IDs supplied by the client alone" (Set
      // 23 section 2 / Set 24 section 8) - the assignment list is the
      // source of truth regardless of what a caller claims it wants to
      // operate on. Covers every one of Set 24 section 8's manipulated-id
      // scenarios that this module can enforce server-side.
      final assignments = [
        _assignment(
          academicSessionId: 's1',
          classId: 'c1',
          subjectId: 'hindi',
          batchId: 'homeroom',
        ),
      ];
      for (final attempt in [
        (sessionId: 's2', classId: 'c1', batchId: 'homeroom', subjectId: 'hindi'),
        (sessionId: 's1', classId: 'c2', batchId: 'homeroom', subjectId: 'hindi'),
        (sessionId: 's1', classId: 'c1', batchId: 'otherBatch', subjectId: 'hindi'),
        (sessionId: 's1', classId: 'c1', batchId: 'homeroom', subjectId: 'english'),
      ]) {
        expect(
          teacherCanOperateOn(
            assignments,
            academicSessionId: attempt.sessionId,
            classId: attempt.classId,
            batchId: attempt.batchId,
            subjectId: attempt.subjectId,
          ),
          isFalse,
          reason: 'attempt $attempt must be denied',
        );
      }
    });

    test('an assignment for a DIFFERENT teacher never grants scope - a caller must supply only their OWN assignments', () {
      // teacherCanOperateOn takes whatever assignment list the caller
      // passes in - the real protection against teacherId spoofing is
      // that every call site sources this list from
      // `ownTeacherAssignmentsProvider(currentUserAccount.uid)`
      // (server-side, rule-constrained to `teacherId ==
      // request.auth.uid`), never from a client-writable field. This
      // test documents that expectation: even if a caller mistakenly
      // passed another teacher's assignments, the function itself has no
      // notion of "my own" teacherId to filter by, so callers MUST do
      // that filtering via the correct provider, not by trusting a
      // teacherId value.
      final otherTeachersAssignment = _assignment(teacherId: 't2');
      expect(otherTeachersAssignment.teacherId, isNot('t1'));
      // teacherCanOperateOn correctly still finds a scope match here
      // (it does not check teacherId at all) - proving that identity
      // filtering is NOT this function's job. It is the CALLER's job to
      // never pass any assignment except the current teacher's own.
      expect(
        teacherCanOperateOn(
          [otherTeachersAssignment],
          academicSessionId: 's1',
          classId: 'c1',
          batchId: 'b1',
          subjectId: 'math',
        ),
        isTrue,
      );
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
          classId: 'c1',
          batchId: 'b1',
          subjectId: 'math',
        ),
        isFalse,
      );
    });
  });
}
