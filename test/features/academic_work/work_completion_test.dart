import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/features/academic_work/data/academic_work.dart';
import 'package:omega_epr_v2/features/academic_work/data/work_completion.dart';
import 'package:omega_epr_v2/features/academic_work/data/work_completion_message.dart';

WorkCompletion _completion({
  WorkCompletionStatus status = WorkCompletionStatus.completed,
  String studentUid = 'stu1',
  String? remark,
  DateTime? seenAt,
}) {
  return WorkCompletion(
    workId: 'work1',
    studentUid: studentUid,
    batchId: 'batch1',
    status: status,
    remark: remark,
    markedBy: 'teacher1',
    markedAt: DateTime(2026, 9, 18, 10),
    seenAt: seenAt,
  );
}

void main() {
  group('WorkCompletion', () {
    test('id is deterministic per work + student', () {
      expect(_completion().id, 'work1_stu1');
      expect(
        WorkCompletion.idFor(workId: 'w', studentUid: 's'),
        WorkCompletion.idFor(workId: 'w', studentUid: 's'),
      );
    });

    test('round-trips through toMap/fromMap, including seenAt', () {
      final original = _completion(
        status: WorkCompletionStatus.incomplete,
        remark: 'Finish Q4',
        seenAt: DateTime(2026, 9, 19),
      );
      final restored = WorkCompletion.fromMap(original.id, original.toMap());

      expect(restored.status, WorkCompletionStatus.incomplete);
      expect(restored.remark, 'Finish Q4');
      expect(restored.seenAt, DateTime(2026, 9, 19));
      expect(restored.markedBy, 'teacher1');
      expect(restored.batchId, 'batch1');
    });

    test('a fresh record is unseen until the student dismisses it', () {
      expect(_completion().isUnseen, isTrue);
      expect(_completion(seenAt: DateTime(2026, 9, 19)).isUnseen, isFalse);
    });

    test('fromMap rejects an unknown status', () {
      final map = _completion().toMap()..['status'] = 'pending';
      expect(() => WorkCompletion.fromMap('x', map), throwsArgumentError);
    });
  });

  group('WorkCompletionSummary', () {
    test('counts each status and derives not-marked from the roster', () {
      final summary = WorkCompletionSummary.of([
        _completion(studentUid: 'a'),
        _completion(studentUid: 'b'),
        _completion(studentUid: 'c', status: WorkCompletionStatus.incomplete),
        _completion(studentUid: 'd', status: WorkCompletionStatus.notCompleted),
      ], studentCount: 10);

      expect(summary.completed, 2);
      expect(summary.incomplete, 1);
      expect(summary.notCompleted, 1);
      expect(summary.notMarked, 6);
      expect(summary.total, 10);
    });

    test('never reports a negative not-marked count', () {
      final summary = WorkCompletionSummary.of([
        _completion(studentUid: 'a'),
        _completion(studentUid: 'b'),
      ], studentCount: 1);

      expect(summary.notMarked, 0);
    });
  });

  group('buildWorkCompletionMessage', () {
    final dueDate = DateTime(2026, 9, 25);

    WorkCompletionMessage build(
      WorkCompletionStatus status, {
      DateTime? now,
      String? remark,
      AcademicWorkType type = AcademicWorkType.homework,
    }) {
      return buildWorkCompletionMessage(
        status: status,
        type: type,
        title: 'Chapter 5',
        subject: 'Maths',
        dueDate: dueDate,
        now: now ?? DateTime(2026, 9, 20),
        remark: remark,
      );
    }

    test('completed: congratulates in English and Hindi', () {
      final message = build(WorkCompletionStatus.completed);

      expect(message.english, contains('Well done'));
      expect(message.english, contains('"Chapter 5" (Maths)'));
      expect(message.english, contains('completed'));
      expect(message.hindi, contains('शाबाश'));
      expect(message.hindi, contains('"Chapter 5" (Maths)'));
      expect(message.hindi, contains('होमवर्क'));
    });

    test('incomplete before the due date asks to finish by that date', () {
      final message = build(WorkCompletionStatus.incomplete);

      expect(message.english, contains('is incomplete'));
      expect(message.english, contains('by 25 Sep 2026'));
      expect(message.hindi, contains('अधूरा'));
      expect(message.hindi, contains('25 Sep 2026 तक'));
    });

    test(
      'incomplete after the due date asks to finish as soon as possible',
      () {
        final message = build(
          WorkCompletionStatus.incomplete,
          now: DateTime(2026, 9, 26),
        );

        expect(message.english, contains('has passed'));
        expect(message.english, contains('as soon as possible'));
        expect(message.hindi, contains('जल्द से जल्द'));
      },
    );

    test('incomplete on the due date itself is not yet past due', () {
      final message = build(
        WorkCompletionStatus.incomplete,
        now: DateTime(2026, 9, 25, 18),
      );

      expect(message.english, contains('by 25 Sep 2026'));
    });

    test('not completed asks to complete and submit', () {
      final message = build(WorkCompletionStatus.notCompleted);

      expect(message.english, contains('was not completed'));
      expect(message.english, contains('submit it to your teacher'));
      expect(message.hindi, contains('पूरा नहीं हुआ'));
    });

    test('an assignment says assignment / असाइनमेंट', () {
      final message = build(
        WorkCompletionStatus.completed,
        type: AcademicWorkType.assignment,
      );

      expect(message.english, contains('Assignment'));
      expect(message.hindi, contains('असाइनमेंट'));
    });

    test('a teacher remark is appended in both languages', () {
      final message = build(
        WorkCompletionStatus.incomplete,
        remark: 'Redo question 4',
      );

      expect(message.english, endsWith("Teacher's remark: Redo question 4"));
      expect(message.hindi, endsWith('शिक्षक की टिप्पणी: Redo question 4'));
    });

    test('a blank remark adds nothing', () {
      final message = build(WorkCompletionStatus.completed, remark: '   ');

      expect(message.english, isNot(contains('remark')));
      expect(message.hindi, isNot(contains('टिप्पणी')));
    });
  });
}
