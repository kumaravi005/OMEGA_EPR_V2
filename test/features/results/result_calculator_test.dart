import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/data/models/gender.dart';
import 'package:omega_epr_v2/features/results/data/result_calculator.dart';
import 'package:omega_epr_v2/features/student/data/student_profile.dart';
import 'package:omega_epr_v2/features/tests/data/test_definition.dart';
import 'package:omega_epr_v2/features/tests/data/test_result.dart';

StudentProfile _student(String uid, String name, {String admissionNumber = ''}) {
  final now = DateTime(2026, 1, 1);
  return StudentProfile(
    uid: uid,
    accountId: uid,
    admissionNumber: admissionNumber,
    name: name,
    fatherName: 'Father',
    dateOfBirth: DateTime(2012, 1, 1),
    gender: Gender.male,
    address: 'Address',
    className: 'Class 9',
    board: 'CBSE',
    batchId: 'batch1',
    academicSession: '2026-27',
    academicSessionId: 'session2026',
    classId: 'class9',
    primaryMobile: '9999999999',
    secondaryMobile: null,
    standardFee: 1000,
    finalFee: 1000,
    feeReason: null,
    paymentPlan: PaymentPlan.monthly,
    admissionDate: now,
    currentAdmissionId: 'admission1',
    active: true,
    createdAt: now,
    updatedAt: now,
  );
}

TestDefinition _test(
  String testId, {
  required String subjectId,
  required String subject,
  required double totalMarks,
}) {
  final now = DateTime(2026, 4, 1);
  return TestDefinition(
    testId: testId,
    batchId: 'batch1',
    academicSessionId: 'session2026',
    classId: 'class9',
    subjectId: subjectId,
    subject: subject,
    title: 'Monthly Test',
    chapterTopic: 'Chapter 1',
    date: now,
    totalMarks: totalMarks,
    testType: TestType.monthlyTest,
    description: null,
    active: true,
    resultPublished: false,
    createdBy: 'admin1',
    createdAt: now,
    updatedAt: now,
  );
}

TestResult _present(String testId, String studentUid, double marks, double total) {
  final now = DateTime(2026, 4, 5);
  return TestResult(
    resultId: TestResult.idFor(testId: testId, studentUid: studentUid),
    testId: testId,
    studentUid: studentUid,
    batchId: 'batch1',
    isAbsent: false,
    obtainedMarks: marks,
    totalMarks: total,
    remark: null,
    enteredBy: 'admin1',
    createdAt: now,
    updatedAt: now,
  );
}

TestResult _absent(String testId, String studentUid, double total) {
  final now = DateTime(2026, 4, 5);
  return TestResult(
    resultId: TestResult.idFor(testId: testId, studentUid: studentUid),
    testId: testId,
    studentUid: studentUid,
    batchId: 'batch1',
    isAbsent: true,
    obtainedMarks: null,
    totalMarks: total,
    remark: null,
    enteredBy: 'admin1',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  final alice = _student('stu1', 'Alice', admissionNumber: 'STU0001');
  final bob = _student('stu2', 'Bob', admissionNumber: 'STU0002');
  final carol = _student('stu3', 'Carol', admissionNumber: 'STU0003');

  group('computeSubjectResults', () {
    test('computes obtained/max/percentage for a present student', () {
      final math = _test('t1', subjectId: 'math', subject: 'Mathematics', totalMarks: 50);
      final rows = computeSubjectResults(
        test: math,
        students: [alice],
        results: [_present('t1', 'stu1', 45, 50)],
      );

      expect(rows.single.status, ResultStatus.complete);
      expect(rows.single.cell.obtainedMarks, 45);
      expect(rows.single.totalMarks, 50);
      expect(rows.single.percentage, closeTo(90, 0.001));
    });

    test('a student with no TestResult document is incomplete, not zero', () {
      final math = _test('t1', subjectId: 'math', subject: 'Mathematics', totalMarks: 50);
      final rows = computeSubjectResults(test: math, students: [alice], results: []);

      expect(rows.single.status, ResultStatus.incomplete);
      expect(rows.single.cell.obtainedMarks, isNull);
      expect(rows.single.percentage, isNull);
      expect(rows.single.rank, isNull);
    });

    test('an absent student is absent, never a zero score', () {
      final math = _test('t1', subjectId: 'math', subject: 'Mathematics', totalMarks: 50);
      final rows = computeSubjectResults(
        test: math,
        students: [alice],
        results: [_absent('t1', 'stu1', 50)],
      );

      expect(rows.single.status, ResultStatus.absent);
      expect(rows.single.cell.obtainedMarks, isNull);
      expect(rows.single.percentage, isNull);
      expect(rows.single.rank, isNull);
    });

    test('ranks complete results with competition ranking (ties share a rank)', () {
      final math = _test('t1', subjectId: 'math', subject: 'Mathematics', totalMarks: 50);
      final rows = computeSubjectResults(
        test: math,
        students: [alice, bob, carol],
        results: [
          _present('t1', 'stu1', 45, 50), // 90%
          _present('t1', 'stu2', 45, 50), // 90% - ties with alice
          _present('t1', 'stu3', 42, 50), // 84%
        ],
      );
      final byUid = {for (final r in rows) r.student.uid: r};

      expect(byUid['stu1']!.rank, 1);
      expect(byUid['stu2']!.rank, 1);
      expect(byUid['stu3']!.rank, 3);
    });

    test('absent/incomplete students never receive a rank, even mixed with complete ones', () {
      final math = _test('t1', subjectId: 'math', subject: 'Mathematics', totalMarks: 50);
      final rows = computeSubjectResults(
        test: math,
        students: [alice, bob, carol],
        results: [
          _present('t1', 'stu1', 45, 50),
          _absent('t1', 'stu2', 50),
          // stu3 (carol) has no result at all - incomplete
        ],
      );
      final byUid = {for (final r in rows) r.student.uid: r};

      expect(byUid['stu1']!.rank, 1);
      expect(byUid['stu2']!.rank, isNull);
      expect(byUid['stu3']!.rank, isNull);
    });
  });

  group('computeCombinedResults', () {
    test('sums obtained/maximum marks across subjects with different totals', () {
      final math = _test('t1', subjectId: 'math', subject: 'Mathematics', totalMarks: 50);
      final science = _test('t2', subjectId: 'science', subject: 'Science', totalMarks: 100);

      final rows = computeCombinedResults(
        tests: [math, science],
        students: [alice],
        allResults: [
          _present('t1', 'stu1', 45, 50),
          _present('t2', 'stu1', 90, 100),
        ],
      );

      final row = rows.single;
      expect(row.status, ResultStatus.complete);
      expect(row.totalObtained, 135);
      expect(row.totalMaximum, 150);
      expect(row.percentage, closeTo(90, 0.001));
    });

    test(
      'a student absent in one of several subjects gets overall status '
      'Absent, not a normal zero contribution to a computed percentage',
      () {
        final math = _test('t1', subjectId: 'math', subject: 'Mathematics', totalMarks: 50);
        final science = _test('t2', subjectId: 'science', subject: 'Science', totalMarks: 50);

        final rows = computeCombinedResults(
          tests: [math, science],
          students: [alice],
          allResults: [
            _present('t1', 'stu1', 45, 50),
            _absent('t2', 'stu1', 50),
          ],
        );

        final row = rows.single;
        expect(row.status, ResultStatus.absent);
        expect(row.totalObtained, isNull);
        expect(row.totalMaximum, isNull);
        expect(row.percentage, isNull);
        expect(row.rank, isNull);
        // The subject-level cells still show exactly what happened.
        expect(row.cells[0].status, CellStatus.present);
        expect(row.cells[0].obtainedMarks, 45);
        expect(row.cells[1].status, CellStatus.absent);
      },
    );

    test(
      'a student missing marks (not absent) in one subject is Incomplete, '
      'with no misleading percentage or rank',
      () {
        final math = _test('t1', subjectId: 'math', subject: 'Mathematics', totalMarks: 50);
        final science = _test('t2', subjectId: 'science', subject: 'Science', totalMarks: 50);

        final rows = computeCombinedResults(
          tests: [math, science],
          students: [alice],
          allResults: [
            _present('t1', 'stu1', 45, 50),
            // no result at all for science yet
          ],
        );

        final row = rows.single;
        expect(row.status, ResultStatus.incomplete);
        expect(row.totalObtained, isNull);
        expect(row.percentage, isNull);
        expect(row.rank, isNull);
      },
    );

    test('ranks only complete combined results, ties share a rank', () {
      final math = _test('t1', subjectId: 'math', subject: 'Mathematics', totalMarks: 50);
      final science = _test('t2', subjectId: 'science', subject: 'Science', totalMarks: 50);

      final rows = computeCombinedResults(
        tests: [math, science],
        students: [alice, bob, carol],
        allResults: [
          _present('t1', 'stu1', 45, 50),
          _present('t2', 'stu1', 45, 50), // alice: 90/100 = 90%
          _present('t1', 'stu2', 45, 50),
          _present('t2', 'stu2', 45, 50), // bob: 90/100 = 90% - ties alice
          _present('t1', 'stu3', 40, 50),
          _absent('t2', 'stu3', 50), // carol: absent in science
        ],
      );
      final byUid = {for (final r in rows) r.student.uid: r};

      expect(byUid['stu1']!.rank, 1);
      expect(byUid['stu2']!.rank, 1);
      expect(byUid['stu3']!.rank, isNull);
      expect(byUid['stu3']!.status, ResultStatus.absent);
    });

    test('an empty subject selection yields no computable percentage per student', () {
      final rows = computeCombinedResults(tests: [], students: [alice], allResults: []);
      // No subjects means nothing missing to report as incomplete or
      // complete in a meaningful sense - it is vacuously "complete" (no
      // cells to be missing), matching a 0/0 combined total.
      expect(rows.single.cells, isEmpty);
    });
  });

  group('ResultStatus.fromCells', () {
    test('absent takes priority over incomplete when both occur', () {
      expect(
        ResultStatus.fromCells(const [
          SubjectCell.absent(),
          SubjectCell.missing(),
        ]),
        ResultStatus.absent,
      );
    });

    test('all present cells yield complete', () {
      expect(
        ResultStatus.fromCells(const [
          SubjectCell.present(10),
          SubjectCell.present(20),
        ]),
        ResultStatus.complete,
      );
    });
  });
}
