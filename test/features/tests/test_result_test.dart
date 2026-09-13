import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/features/tests/application/test_controller.dart';
import 'package:omega_epr_v2/features/tests/data/test_definition.dart';
import 'package:omega_epr_v2/features/tests/data/test_result.dart';

TestDefinition _test({required double totalMarks}) {
  final now = DateTime(2026, 1, 1);
  return TestDefinition(
    testId: 'test1',
    batchId: 'batch1',
    academicSessionId: 'session2026',
    classId: 'class9',
    subjectId: 'mathematics',
    subject: 'Mathematics',
    title: 'Unit Test 1',
    chapterTopic: 'Light',
    date: now,
    totalMarks: totalMarks,
    testType: TestType.unitTest,
    description: null,
    active: true,
    resultPublished: false,
    createdBy: 'admin1',
    createdAt: now,
    updatedAt: now,
  );
}

TestResult _result({double? obtainedMarks, bool isAbsent = false}) {
  final now = DateTime(2026, 1, 1);
  return TestResult(
    resultId: 'test1_stu1',
    testId: 'test1',
    studentUid: 'stu1',
    batchId: 'batch1',
    isAbsent: isAbsent,
    obtainedMarks: obtainedMarks,
    totalMarks: 50,
    remark: null,
    enteredBy: 'admin1',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('TestResult.percentage', () {
    test('computes obtained/total as a percentage', () {
      expect(_result(obtainedMarks: 45).percentage, 90);
    });

    test('is zero when total marks is zero, never divides by zero', () {
      final now = DateTime(2026, 1, 1);
      final result = TestResult(
        resultId: 'r1',
        testId: 'test1',
        studentUid: 'stu1',
        batchId: 'batch1',
        isAbsent: false,
        obtainedMarks: 0,
        totalMarks: 0,
        remark: null,
        enteredBy: 'admin1',
        createdAt: now,
        updatedAt: now,
      );
      expect(result.percentage, 0);
    });

    test('is null (not zero) when the student is absent', () {
      expect(_result(isAbsent: true).percentage, isNull);
    });
  });

  test(
    'TestResult.idFor is deterministic per test+student, preventing duplicate marks',
    () {
      expect(
        TestResult.idFor(testId: 'test1', studentUid: 'stu1'),
        'test1_stu1',
      );
    },
  );

  test('round-trips through toMap/fromMap, including isAbsent', () {
    final absent = _result(isAbsent: true);
    final restoredAbsent = TestResult.fromMap(
      absent.resultId,
      absent.toMap(),
    );
    expect(restoredAbsent.isAbsent, isTrue);
    expect(restoredAbsent.obtainedMarks, isNull);

    final present = _result(obtainedMarks: 38);
    final restoredPresent = TestResult.fromMap(
      present.resultId,
      present.toMap(),
    );
    expect(restoredPresent.isAbsent, isFalse);
    expect(restoredPresent.obtainedMarks, 38);
  });

  test(
    'fromMap defaults isAbsent to false on a pre-Set-14 document with a '
    'plain numeric obtainedMarks',
    () {
      final now = Timestamp.fromDate(DateTime(2025, 1, 1));
      final restored = TestResult.fromMap('test1_stu1', {
        'testId': 'test1',
        'studentUid': 'stu1',
        'batchId': 'batch1',
        'obtainedMarks': 42,
        'totalMarks': 50,
        'enteredBy': 'admin1',
        'createdAt': now,
        'updatedAt': now,
      });

      expect(restored.isAbsent, isFalse);
      expect(restored.obtainedMarks, 42);
    },
  );

  group('TestController.saveMarksBulk validation', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('rejects negative obtained marks', () async {
      final controller = container.read(testControllerProvider);
      expect(
        () => controller.saveMarksBulk(
          test: _test(totalMarks: 50),
          entries: {
            'stu1': const MarkEntry(isAbsent: false, obtainedMarks: -5),
          },
        ),
        throwsA(
          isA<TestActionFailure>().having(
            (f) => f.message,
            'message',
            contains('cannot be negative'),
          ),
        ),
      );
    });

    test('rejects obtained marks exceeding the total', () async {
      final controller = container.read(testControllerProvider);
      expect(
        () => controller.saveMarksBulk(
          test: _test(totalMarks: 50),
          entries: {
            'stu1': const MarkEntry(isAbsent: false, obtainedMarks: 55),
          },
        ),
        throwsA(
          isA<TestActionFailure>().having(
            (f) => f.message,
            'message',
            contains('cannot exceed'),
          ),
        ),
      );
    });

    test('an absent entry is never checked against the marks range', () async {
      final controller = container.read(testControllerProvider);
      // Absent entries skip range validation entirely - the failure that
      // does surface (no signed-in user, in this bare test container)
      // proves validation passed through to the auth check rather than
      // rejecting the absent entry itself.
      await expectLater(
        controller.saveMarksBulk(
          test: _test(totalMarks: 50),
          entries: {'stu1': const MarkEntry(isAbsent: true)},
        ),
        throwsA(
          isA<TestActionFailure>().having(
            (f) => f.message,
            'message',
            contains('sign in'),
          ),
        ),
      );
    });
  });

  group('TestController.createTest validation', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('rejects a total marks of zero or less', () async {
      final controller = container.read(testControllerProvider);
      expect(
        () => controller.createTest(
          batchId: 'batch1',
          academicSessionId: 'session2026',
          classId: 'class9',
          subjectId: 'mathematics',
          subjectName: 'Mathematics',
          title: 'Unit Test 1',
          chapterTopic: 'Light',
          date: DateTime(2026, 1, 1),
          totalMarks: 0,
          testType: TestType.unitTest,
          description: null,
        ),
        throwsA(isA<TestActionFailure>()),
      );
    });
  });
}
