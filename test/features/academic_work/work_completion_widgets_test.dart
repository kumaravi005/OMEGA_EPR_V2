import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/core/theme/app_colors.dart';
import 'package:omega_epr_v2/features/academic_work/data/academic_work.dart';
import 'package:omega_epr_v2/features/academic_work/data/work_completion.dart';
import 'package:omega_epr_v2/features/academic_work/data/work_completion_repository.dart';
import 'package:omega_epr_v2/features/academic_work/presentation/work_completion_message_card.dart';
import 'package:omega_epr_v2/features/academic_work/presentation/work_completion_style.dart';

WorkCompletionView _view(
  WorkCompletionStatus status, {
  String? remark,
  DateTime? dueDate,
}) {
  final now = DateTime(2026, 9, 18);
  return WorkCompletionView(
    completion: WorkCompletion(
      workId: 'work1',
      studentUid: 'stu1',
      batchId: 'batch1',
      status: status,
      remark: remark,
      markedBy: 'teacher1',
      markedAt: now,
    ),
    work: AcademicWork(
      workId: 'work1',
      type: AcademicWorkType.homework,
      academicSessionId: 's',
      classId: 'c',
      batchId: 'batch1',
      subjectId: 'sub',
      subject: 'Maths',
      title: 'Chapter 5',
      assignedDate: now,
      dueDate: dueDate ?? DateTime(2099, 1, 1),
      status: AcademicWorkStatus.published,
      createdBy: 'teacher1',
      createdAt: now,
      updatedAt: now,
    ),
  );
}

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Color _cardColor(WidgetTester tester) {
  final container = tester.widget<Container>(
    find
        .descendant(
          of: find.byType(WorkCompletionMessageCard),
          matching: find.byType(Container),
        )
        .first,
  );
  return (container.decoration! as BoxDecoration).color!;
}

void main() {
  group('WorkCompletionMessageCard', () {
    testWidgets('completed is green and shows English and Hindi', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          WorkCompletionMessageCard(
            view: _view(WorkCompletionStatus.completed),
          ),
        ),
      );

      expect(_cardColor(tester), AppColors.successSoft);
      expect(find.text('Completed · पूरा'), findsOneWidget);
      expect(find.textContaining('Well done!'), findsOneWidget);
      expect(find.textContaining('शाबाश'), findsOneWidget);
    });

    testWidgets('incomplete is yellow and asks to finish by the due date', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          WorkCompletionMessageCard(
            view: _view(WorkCompletionStatus.incomplete),
          ),
        ),
      );

      expect(_cardColor(tester), AppColors.warningSoft);
      expect(find.text('Incomplete · अधूरा'), findsOneWidget);
      expect(
        find.textContaining('Please complete it by 1 Jan 2099.'),
        findsOneWidget,
      );
    });

    testWidgets('not completed is red and shows the teacher remark', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          WorkCompletionMessageCard(
            view: _view(WorkCompletionStatus.notCompleted, remark: 'Redo Q4'),
          ),
        ),
      );

      expect(_cardColor(tester), AppColors.dangerSoft);
      expect(find.text('Not completed · पूरा नहीं'), findsOneWidget);
      expect(find.textContaining("Teacher's remark: Redo Q4"), findsOneWidget);
      expect(find.textContaining('शिक्षक की टिप्पणी: Redo Q4'), findsOneWidget);
    });
  });

  group('WorkCompletionSummaryRow', () {
    testWidgets('shows all four counts', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const WorkCompletionSummaryRow(
            summary: WorkCompletionSummary(
              completed: 18,
              incomplete: 4,
              notCompleted: 2,
              notMarked: 6,
            ),
          ),
        ),
      );

      expect(find.text('Completed 18'), findsOneWidget);
      expect(find.text('Incomplete 4'), findsOneWidget);
      expect(find.text('Not completed 2'), findsOneWidget);
      expect(find.text('Not marked 6'), findsOneWidget);
    });
  });
}
