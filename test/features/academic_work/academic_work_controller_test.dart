import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/features/academic_work/application/academic_work_controller.dart';
import 'package:omega_epr_v2/features/academic_work/data/academic_work.dart';

void main() {
  group('AcademicWorkController.create validation', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('rejects a due date before the assigned date', () {
      final controller = container.read(academicWorkControllerProvider);
      expect(
        () => controller.create(
          type: AcademicWorkType.homework,
          academicSessionId: 'session2026',
          classId: 'class9',
          batchId: 'batch1',
          subjectId: 'mathematics',
          subjectName: 'Mathematics',
          title: 'Chapter 3',
          assignedDate: DateTime(2026, 4, 10),
          dueDate: DateTime(2026, 4, 5),
          status: AcademicWorkStatus.published,
        ),
        throwsA(
          isA<AcademicWorkFailure>().having(
            (f) => f.message,
            'message',
            contains('cannot be before'),
          ),
        ),
      );
    });

    test('a due date equal to the assigned date is accepted', () {
      final controller = container.read(academicWorkControllerProvider);
      // Same-day due date must pass the date check and fail only on the
      // (expected, in this bare test container) missing signed-in user -
      // proving the date validation itself did not reject it.
      expect(
        () => controller.create(
          type: AcademicWorkType.homework,
          academicSessionId: 'session2026',
          classId: 'class9',
          batchId: 'batch1',
          subjectId: 'mathematics',
          subjectName: 'Mathematics',
          title: 'Chapter 3',
          assignedDate: DateTime(2026, 4, 10),
          dueDate: DateTime(2026, 4, 10),
          status: AcademicWorkStatus.published,
        ),
        throwsA(
          isA<AcademicWorkFailure>().having(
            (f) => f.message,
            'message',
            isNot(contains('cannot be before')),
          ),
        ),
      );
    });

    test('rejects creating an item that is already closed', () {
      final controller = container.read(academicWorkControllerProvider);
      expect(
        () => controller.create(
          type: AcademicWorkType.assignment,
          academicSessionId: 'session2026',
          classId: 'class9',
          batchId: 'batch1',
          subjectId: 'mathematics',
          subjectName: 'Mathematics',
          title: 'Chapter 3',
          assignedDate: DateTime(2026, 4, 10),
          dueDate: DateTime(2026, 4, 15),
          status: AcademicWorkStatus.closed,
        ),
        throwsA(
          isA<AcademicWorkFailure>().having(
            (f) => f.message,
            'message',
            contains('already closed'),
          ),
        ),
      );
    });
  });

  group('AcademicWorkController.update validation', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('rejects a due date before the assigned date', () {
      final controller = container.read(academicWorkControllerProvider);
      final now = DateTime(2026, 1, 1);
      final existing = AcademicWork(
        workId: 'work1',
        type: AcademicWorkType.homework,
        academicSessionId: 'session2026',
        classId: 'class9',
        batchId: 'batch1',
        subjectId: 'mathematics',
        subject: 'Mathematics',
        title: 'Chapter 3',
        assignedDate: now,
        dueDate: now,
        status: AcademicWorkStatus.published,
        createdBy: 'admin1',
        createdAt: now,
        updatedAt: now,
      );

      expect(
        () => controller.update(
          existing: existing,
          title: 'Chapter 3',
          assignedDate: DateTime(2026, 4, 10),
          dueDate: DateTime(2026, 4, 5),
        ),
        throwsA(
          isA<AcademicWorkFailure>().having(
            (f) => f.message,
            'message',
            contains('cannot be before'),
          ),
        ),
      );
    });
  });
}
