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
    subject: 'Science',
    title: 'Unit Test 1',
    chapterTopic: 'Light',
    date: now,
    totalMarks: totalMarks,
    testType: TestType.objective,
    description: null,
    resultPublished: false,
    createdBy: 'teacher1',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('TestResult.percentage', () {
    test('computes obtained/total as a percentage', () {
      final now = DateTime(2026, 1, 1);
      final result = TestResult(
        resultId: 'r1',
        testId: 'test1',
        studentUid: 'stu1',
        batchId: 'batch1',
        obtainedMarks: 45,
        totalMarks: 50,
        remark: null,
        enteredBy: 'teacher1',
        createdAt: now,
        updatedAt: now,
      );
      expect(result.percentage, 90);
    });

    test('is zero when total marks is zero, never divides by zero', () {
      final now = DateTime(2026, 1, 1);
      final result = TestResult(
        resultId: 'r1',
        testId: 'test1',
        studentUid: 'stu1',
        batchId: 'batch1',
        obtainedMarks: 0,
        totalMarks: 0,
        remark: null,
        enteredBy: 'teacher1',
        createdAt: now,
        updatedAt: now,
      );
      expect(result.percentage, 0);
    });
  });

  test('TestResult.idFor is deterministic per test+student, preventing duplicate marks', () {
    expect(TestResult.idFor(testId: 'test1', studentUid: 'stu1'), 'test1_stu1');
  });

  group('TestController.enterMark validation', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('rejects negative obtained marks', () async {
      final controller = container.read(testControllerProvider);
      expect(
        () => controller.enterMark(test: _test(totalMarks: 50), studentUid: 'stu1', obtainedMarks: -5, remark: null),
        throwsA(isA<TestActionFailure>().having((f) => f.message, 'message', contains('cannot be negative'))),
      );
    });

    test('rejects obtained marks exceeding the total', () async {
      final controller = container.read(testControllerProvider);
      expect(
        () => controller.enterMark(test: _test(totalMarks: 50), studentUid: 'stu1', obtainedMarks: 55, remark: null),
        throwsA(isA<TestActionFailure>().having((f) => f.message, 'message', contains('cannot exceed'))),
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
          subject: 'Science',
          title: 'Unit Test 1',
          chapterTopic: 'Light',
          date: DateTime(2026, 1, 1),
          totalMarks: 0,
          testType: TestType.objective,
          description: null,
        ),
        throwsA(isA<TestActionFailure>()),
      );
    });
  });
}
