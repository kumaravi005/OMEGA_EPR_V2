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

/// One student's staged mark, before it's written - the shape
/// [TestController.saveMarksBulk] takes for the whole sheet. A student
/// simply absent from this map means "leave their existing record (or
/// lack of one) untouched", not "clear their marks".
class MarkEntry {
  const MarkEntry({required this.isAbsent, this.obtainedMarks, this.remark});

  final bool isAbsent;

  /// Ignored (and never written) when [isAbsent] is `true`.
  final double? obtainedMarks;
  final String? remark;
}

final testControllerProvider = Provider<TestController>(
  (ref) => TestController(ref),
);

class TestController {
  TestController(this._ref);

  final Ref _ref;

  /// Creates a test for a specific academic session/class/batch/subject -
  /// all four by stable id, snapshotted from the selected batch/subject
  /// at creation time (see [TestDefinition]'s doc comment).
  Future<void> createTest({
    required String batchId,
    required String academicSessionId,
    required String classId,
    required String subjectId,
    required String subjectName,
    required String title,
    required String chapterTopic,
    required DateTime date,
    required double totalMarks,
    required TestType testType,
    String? otherTestTypeLabel,
    required String? description,
  }) async {
    if (totalMarks <= 0) {
      throw const TestActionFailure('Total marks must be greater than zero.');
    }
    final admin = _ref.read(currentUserAccountProvider).valueOrNull;
    if (admin == null) throw const TestActionFailure('Please sign in again.');

    try {
      final now = DateTime.now();
      final id = await _ref
          .read(testRepositoryProvider)
          .add(
            TestDefinition(
              testId: '',
              batchId: batchId,
              academicSessionId: academicSessionId,
              classId: classId,
              subjectId: subjectId,
              subject: subjectName.trim(),
              title: title.trim(),
              chapterTopic: chapterTopic.trim(),
              date: date,
              totalMarks: totalMarks,
              testType: testType,
              otherTestTypeLabel: testType == TestType.other
                  ? otherTestTypeLabel?.trim()
                  : null,
              description: description?.trim(),
              active: true,
              resultPublished: false,
              createdBy: admin.uid,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await recordNotificationEvent(
        _ref,
        type: NotificationEventType.test,
        batchId: batchId,
        title: 'New test: $title',
        body: '$subjectName - $chapterTopic',
        relatedId: id,
      );
    } catch (_) {
      throw const TestActionFailure(
        'Could not create the test. Please try again.',
      );
    }
  }

  /// Saves every staged mark in [entries] for [test] in one atomic
  /// `WriteBatch` commit - one network round-trip for the whole sheet,
  /// not one write per student (Set 14 spec: "do not perform unnecessary
  /// individual network writes when saving a complete marks sheet").
  /// Rejects the whole batch (no partial save) if any entry is invalid,
  /// so admin never sees a false "saved" for an incomplete write.
  Future<void> saveMarksBulk({
    required TestDefinition test,
    required Map<String, MarkEntry> entries,
  }) async {
    for (final entry in entries.values) {
      if (entry.isAbsent) continue;
      final marks = entry.obtainedMarks;
      if (marks == null) continue; // not entered yet - skip, don't write
      if (marks < 0) {
        throw const TestActionFailure('Obtained marks cannot be negative.');
      }
      if (marks > test.totalMarks) {
        throw const TestActionFailure(
          'Obtained marks cannot exceed the total marks.',
        );
      }
    }

    final admin = _ref.read(currentUserAccountProvider).valueOrNull;
    if (admin == null) throw const TestActionFailure('Please sign in again.');

    try {
      final repo = _ref.read(testResultRepositoryProvider);
      final writeBatch = repo.collection.firestore.batch();
      final now = DateTime.now();

      for (final studentEntry in entries.entries) {
        final studentUid = studentEntry.key;
        final entry = studentEntry.value;
        // Skip students nobody has touched yet - not absent, no marks
        // typed - rather than writing an empty placeholder document.
        if (!entry.isAbsent && entry.obtainedMarks == null) continue;

        final resultId = TestResult.idFor(
          testId: test.testId,
          studentUid: studentUid,
        );
        final existing = await repo.getById(resultId);
        final record = TestResult(
          resultId: resultId,
          testId: test.testId,
          studentUid: studentUid,
          batchId: test.batchId,
          isAbsent: entry.isAbsent,
          obtainedMarks: entry.isAbsent ? null : entry.obtainedMarks,
          totalMarks: test.totalMarks,
          remark: entry.remark?.trim(),
          enteredBy: admin.uid,
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
        );
        writeBatch.set(repo.collection.doc(resultId), record.toMap());
      }

      await writeBatch.commit();
    } on TestActionFailure {
      rethrow;
    } catch (_) {
      throw const TestActionFailure(
        'Could not save marks. Please try again.',
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

  /// Archives/restores a test without touching its marks - "avoid
  /// destructive deletion... if a test already has marks, do not allow a
  /// casual delete that leaves orphaned marks" (Set 14 spec). An
  /// inactive test simply stops appearing among selectable/default
  /// results; nothing referencing it is ever removed.
  Future<void> setActive(TestDefinition test, bool active) async {
    try {
      await _ref.read(testRepositoryProvider).updateFields(test.testId, {
        'active': active,
        'updatedAt': Timestamp.now(),
      });
    } catch (_) {
      throw const TestActionFailure(
        'Could not update the test. Please try again.',
      );
    }
  }
}
