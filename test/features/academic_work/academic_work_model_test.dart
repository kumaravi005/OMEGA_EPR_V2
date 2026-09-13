import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/features/academic_work/data/academic_work.dart';

AcademicWork _work({
  AcademicWorkType type = AcademicWorkType.homework,
  AcademicWorkStatus status = AcademicWorkStatus.published,
  DateTime? assignedDate,
  DateTime? dueDate,
}) {
  final now = DateTime(2026, 4, 1);
  return AcademicWork(
    workId: 'work1',
    type: type,
    academicSessionId: 'session2026',
    classId: 'class9',
    batchId: 'batch1',
    subjectId: 'mathematics',
    subject: 'Mathematics',
    title: 'Chapter 3 exercises',
    description: 'Complete Q1-Q10',
    assignedDate: assignedDate ?? now,
    dueDate: dueDate ?? now.add(const Duration(days: 3)),
    status: status,
    createdBy: 'admin1',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('round-trips through toMap/fromMap, including type and status', () {
    final work = _work(type: AcademicWorkType.assignment);
    final restored = AcademicWork.fromMap(work.workId, work.toMap());

    expect(restored.type, AcademicWorkType.assignment);
    expect(restored.status, AcademicWorkStatus.published);
    expect(restored.academicSessionId, 'session2026');
    expect(restored.classId, 'class9');
    expect(restored.batchId, 'batch1');
    expect(restored.subjectId, 'mathematics');
    expect(restored.subject, 'Mathematics');
    expect(restored.title, 'Chapter 3 exercises');
    expect(restored.description, 'Complete Q1-Q10');
  });

  test('description survives as null when not provided', () {
    final now = DateTime(2026, 4, 1);
    final work = AcademicWork(
      workId: 'work2',
      type: AcademicWorkType.homework,
      academicSessionId: 'session2026',
      classId: 'class9',
      batchId: 'batch1',
      subjectId: 'mathematics',
      subject: 'Mathematics',
      title: 'No description',
      assignedDate: now,
      dueDate: now,
      status: AcademicWorkStatus.draft,
      createdBy: 'admin1',
      createdAt: now,
      updatedAt: now,
    );

    final restored = AcademicWork.fromMap(work.workId, work.toMap());
    expect(restored.description, isNull);
  });

  group('isOverdue', () {
    test('a published item past its due date is overdue', () {
      final work = _work(
        status: AcademicWorkStatus.published,
        assignedDate: DateTime(2026, 1, 1),
        dueDate: DateTime(2026, 1, 10),
      );
      expect(work.isOverdue(DateTime(2026, 1, 11)), isTrue);
    });

    test('a published item before its due date is not overdue', () {
      final work = _work(
        status: AcademicWorkStatus.published,
        assignedDate: DateTime(2026, 1, 1),
        dueDate: DateTime(2026, 1, 10),
      );
      expect(work.isOverdue(DateTime(2026, 1, 5)), isFalse);
    });

    test('a draft item is never overdue, even past its due date', () {
      final work = _work(
        status: AcademicWorkStatus.draft,
        assignedDate: DateTime(2026, 1, 1),
        dueDate: DateTime(2026, 1, 10),
      );
      expect(work.isOverdue(DateTime(2026, 1, 20)), isFalse);
    });

    test('a closed item is never overdue, even past its due date', () {
      final work = _work(
        status: AcademicWorkStatus.closed,
        assignedDate: DateTime(2026, 1, 1),
        dueDate: DateTime(2026, 1, 10),
      );
      expect(work.isOverdue(DateTime(2026, 1, 20)), isFalse);
    });

    test('overdue is never stored, only computed - the flag is a plain '
        'method, not a persisted field', () {
      final work = _work();
      // toMap() never includes anything overdue-related.
      expect(work.toMap().containsKey('isOverdue'), isFalse);
      expect(work.toMap().containsKey('overdue'), isFalse);
    });
  });
}
