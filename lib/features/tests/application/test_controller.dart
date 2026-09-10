import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/notification_hook.dart';
import '../../auth/application/auth_providers.dart';
import '../data/test_definition.dart';
import '../data/test_repository.dart';
import '../data/test_result.dart';

class TestActionFailure implements Exception {
  const TestActionFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

final testControllerProvider = Provider<TestController>(
  (ref) => TestController(ref),
);

class TestController {
  TestController(this._ref);

  final Ref _ref;

  Future<void> createTest({
    required String batchId,
    required String subject,
    required String title,
    required String chapterTopic,
    required DateTime date,
    required double totalMarks,
    required TestType testType,
    required String? description,
  }) async {
    if (totalMarks <= 0) {
      throw const TestActionFailure('Total marks must be greater than zero.');
    }
    final teacher = _ref.read(currentUserAccountProvider).valueOrNull;
    if (teacher == null) throw const TestActionFailure('Please sign in again.');

    try {
      final now = DateTime.now();
      final id = await _ref
          .read(testRepositoryProvider)
          .add(
            TestDefinition(
              testId: '',
              batchId: batchId,
              subject: subject.trim(),
              title: title.trim(),
              chapterTopic: chapterTopic.trim(),
              date: date,
              totalMarks: totalMarks,
              testType: testType,
              description: description?.trim(),
              resultPublished: false,
              createdBy: teacher.uid,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await recordNotificationEvent(
        _ref,
        type: NotificationEventType.test,
        batchId: batchId,
        title: 'New test: $title',
        body: '$subject - $chapterTopic',
        relatedId: id,
      );
    } catch (_) {
      throw const TestActionFailure(
        'Could not create the test. Please try again.',
      );
    }
  }

  /// Records (or corrects) one student's marks for [test]. Rejects
  /// negative marks and marks that exceed the test's total.
  Future<void> enterMark({
    required TestDefinition test,
    required String studentUid,
    required double obtainedMarks,
    required String? remark,
  }) async {
    if (obtainedMarks < 0) {
      throw const TestActionFailure('Obtained marks cannot be negative.');
    }
    if (obtainedMarks > test.totalMarks) {
      throw const TestActionFailure(
        'Obtained marks cannot exceed the total marks.',
      );
    }

    final teacher = _ref.read(currentUserAccountProvider).valueOrNull;
    if (teacher == null) throw const TestActionFailure('Please sign in again.');

    final id = TestResult.idFor(testId: test.testId, studentUid: studentUid);
    try {
      final existing = await _ref
          .read(testResultRepositoryProvider)
          .getById(id);
      final now = DateTime.now();
      await _ref
          .read(testResultRepositoryProvider)
          .set(
            id,
            TestResult(
              resultId: id,
              testId: test.testId,
              studentUid: studentUid,
              batchId: test.batchId,
              obtainedMarks: obtainedMarks,
              totalMarks: test.totalMarks,
              remark: remark?.trim(),
              enteredBy: teacher.uid,
              createdAt: existing?.createdAt ?? now,
              updatedAt: now,
            ),
          );
    } catch (_) {
      throw const TestActionFailure(
        'Could not save the mark. Please try again.',
      );
    }
  }

  /// Publishes every mark entered so far for [test] - students can only
  /// ever see marks once this has run (see firestore.rules).
  Future<void> publishResult(TestDefinition test) async {
    try {
      await _ref.read(testRepositoryProvider).updateFields(test.testId, {
        'resultPublished': true,
        'updatedAt': Timestamp.now(),
      });
      await recordNotificationEvent(
        _ref,
        type: NotificationEventType.result,
        batchId: test.batchId,
        title: 'Result published: ${test.title}',
        body: '${test.subject} - ${test.chapterTopic}',
        relatedId: test.testId,
      );
    } catch (_) {
      throw const TestActionFailure(
        'Could not publish the result. Please try again.',
      );
    }
  }
}
