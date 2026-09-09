import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../student/data/student_repository.dart';
import '../application/test_controller.dart';
import '../data/test_definition.dart';
import '../data/test_repository.dart';
import '../data/test_result.dart';

/// Teacher/admin enters obtained marks for every student in the test's
/// batch, then publishes the result when ready.
class EnterMarksScreen extends ConsumerWidget {
  const EnterMarksScreen({super.key, required this.testId});

  final String testId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testAsync = ref.watch(testByIdProvider(testId));

    return Scaffold(
      appBar: AppBar(title: const Text('Enter marks')),
      body: SafeArea(
        child: testAsync.when(
          loading: () => const LoadingView(),
          error: (error, stackTrace) => ErrorView(message: 'Could not load the test.\n$error'),
          data: (test) {
            if (test == null) return const ErrorView(message: 'Test not found.');
            return _MarksBody(test: test);
          },
        ),
      ),
    );
  }
}

class _MarksBody extends ConsumerWidget {
  const _MarksBody({required this.test});

  final TestDefinition test;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(allStudentsProvider);
    final resultsAsync = ref.watch(testResultsForTestProvider(test.testId));

    return studentsAsync.when(
      loading: () => const LoadingView(),
      error: (error, stackTrace) => ErrorView(message: 'Could not load students.\n$error'),
      data: (allStudents) {
        final students = allStudents.where((s) => s.batchId == test.batchId && s.active).toList();
        if (students.isEmpty) return const EmptyView(message: 'No students in this batch.');
        final results = resultsAsync.valueOrNull ?? const <TestResult>[];
        final resultsByStudent = {for (final r in results) r.studentUid: r};

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${test.title} - ${test.subject}', style: Theme.of(context).textTheme.titleLarge),
                    Text('${test.chapterTopic} - ${dateKey(test.date)} - out of ${test.totalMarks.toStringAsFixed(0)}'),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Chip(label: Text(test.resultPublished ? 'Result published' : 'Result not published')),
                        const Spacer(),
                        if (!test.resultPublished)
                          AppButton(
                            label: 'Publish result',
                            variant: AppButtonVariant.secondary,
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await ref.read(testControllerProvider).publishResult(test);
                                messenger.showSnackBar(const SnackBar(content: Text('Result published.')));
                              } on TestActionFailure catch (failure) {
                                messenger.showSnackBar(SnackBar(content: Text(failure.message)));
                              }
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                itemCount: students.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, index) {
                  final student = students[index];
                  return _MarkRow(test: test, studentUid: student.uid, studentName: student.name, existing: resultsByStudent[student.uid]);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MarkRow extends ConsumerStatefulWidget {
  const _MarkRow({required this.test, required this.studentUid, required this.studentName, required this.existing});

  final TestDefinition test;
  final String studentUid;
  final String studentName;
  final TestResult? existing;

  @override
  ConsumerState<_MarkRow> createState() => _MarkRowState();
}

class _MarkRowState extends ConsumerState<_MarkRow> {
  late final _marksController = TextEditingController(text: widget.existing?.obtainedMarks.toStringAsFixed(0) ?? '');
  late final _remarkController = TextEditingController(text: widget.existing?.remark ?? '');
  bool _isSaving = false;

  @override
  void dispose() {
    _marksController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final marks = double.tryParse(_marksController.text);
    if (marks == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid mark.')));
      return;
    }
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(testControllerProvider)
          .enterMark(
            test: widget.test,
            studentUid: widget.studentUid,
            obtainedMarks: marks,
            remark: _remarkController.text.trim().isEmpty ? null : _remarkController.text,
          );
      messenger.showSnackBar(const SnackBar(content: Text('Mark saved.')));
    } on TestActionFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            Expanded(flex: 2, child: Text(widget.studentName)),
            SizedBox(
              width: 80,
              child: TextField(
                controller: _marksController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: '/ ${widget.test.totalMarks.toStringAsFixed(0)}'),
                enabled: !_isSaving,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _remarkController,
                decoration: const InputDecoration(labelText: 'Remark'),
                enabled: !_isSaving,
              ),
            ),
            IconButton(
              icon: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              onPressed: _isSaving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
