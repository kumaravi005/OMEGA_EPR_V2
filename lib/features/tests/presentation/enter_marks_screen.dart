import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/data/user_account.dart';
import '../../student/data/student_profile.dart';
import '../../student/data/student_repository.dart';
import '../../teacher_assignments/data/teacher_assignment_repository.dart';
import '../application/test_controller.dart';
import '../data/test_definition.dart';
import '../data/test_repository.dart';
import '../data/test_result.dart';

/// Bulk marks entry for every eligible student in the test's batch,
/// staged locally and saved together in one write (Set 14 spec) -
/// mirroring the attendance-marking screens' date-then-list-then-save
/// flow. Editable by admin, or by a teacher whose own active
/// `TeacherAssignment` matches this test's session/class/batch/subject
/// (Set 22/23 - previously admin-only); read-only for everyone else,
/// including a teacher with no matching assignment (Set 23 section 11:
/// "do not trust the test ID alone").
class EnterMarksScreen extends ConsumerWidget {
  const EnterMarksScreen({super.key, required this.testId});

  final String testId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testAsync = ref.watch(testByIdProvider(testId));

    return Scaffold(
      appBar: AppBar(title: const Text('Marks')),
      body: SafeArea(
        child: testAsync.when(
          loading: () => const LoadingView(),
          error: (error, stackTrace) =>
              ErrorView(message: 'Could not load the test.\n$error'),
          data: (test) {
            if (test == null) {
              return const ErrorView(message: 'Test not found.');
            }
            return _MarksBody(test: test);
          },
        ),
      ),
    );
  }
}

class _MarksBody extends ConsumerStatefulWidget {
  const _MarksBody({required this.test});

  final TestDefinition test;

  @override
  ConsumerState<_MarksBody> createState() => _MarksBodyState();
}

class _MarksBodyState extends ConsumerState<_MarksBody> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _absent = {};
  bool _prefilled = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _prefillIfNeeded(List<String> studentUids, List<TestResult> results) {
    if (_prefilled) return;
    _prefilled = true;
    final byStudent = {for (final r in results) r.studentUid: r};
    for (final uid in studentUids) {
      final existing = byStudent[uid];
      _controllers[uid] = TextEditingController(
        text: existing?.obtainedMarks?.toStringAsFixed(0) ?? '',
      );
      _absent[uid] = existing?.isAbsent ?? false;
    }
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final entries = <String, MarkEntry>{};
    for (final uid in _controllers.keys) {
      final isAbsent = _absent[uid] ?? false;
      final text = _controllers[uid]!.text.trim();
      final marks = text.isEmpty ? null : double.tryParse(text);
      if (!isAbsent && text.isNotEmpty && marks == null) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Enter a valid number for every mark.';
        });
        return;
      }
      entries[uid] = MarkEntry(isAbsent: isAbsent, obtainedMarks: marks);
    }

    try {
      await ref
          .read(testControllerProvider)
          .saveMarksBulk(test: widget.test, entries: entries);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Marks saved.')));
    } on TestActionFailure catch (failure) {
      setState(() => _errorMessage = failure.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(currentUserAccountProvider).valueOrNull;
    final isAdmin = account?.role == UserRole.admin;
    final isTeacher = account?.role == UserRole.teacher;
    final teacherCanManage = isTeacher && account != null
        ? teacherCanOperateOn(
            ref.watch(ownTeacherAssignmentsProvider(account.uid)).valueOrNull ??
                const [],
            academicSessionId: widget.test.academicSessionId,
            batchId: widget.test.batchId,
            subjectId: widget.test.subjectId,
          )
        : false;
    final canManage = isAdmin || teacherCanManage;
    final studentsAsync = ref.watch(allStudentsProvider);
    final resultsAsync = ref.watch(testResultsForTestProvider(widget.test.testId));

    return studentsAsync.when(
      loading: () => const LoadingView(),
      error: (error, stackTrace) =>
          ErrorView(message: 'Could not load students.\n$error'),
      data: (allStudents) {
        final results = resultsAsync.valueOrNull ?? const <TestResult>[];

        // Active students currently in this batch, plus anyone already
        // marked for this test even if they have since left the batch/
        // gone inactive - re-opening a test must never silently drop
        // them from view (Set 14 spec, matching Set 13's attendance
        // precedent).
        final activeInBatch = allStudents
            .where((s) => s.batchId == widget.test.batchId && s.active)
            .toList();
        final markedUids = results.map((r) => r.studentUid).toSet();
        final historicalExtras = allStudents
            .where(
              (s) =>
                  markedUids.contains(s.uid) &&
                  !activeInBatch.any((a) => a.uid == s.uid),
            )
            .toList();
        final students = [...activeInBatch, ...historicalExtras];

        if (students.isEmpty) {
          return const EmptyView(message: 'No students in this batch.');
        }

        _prefillIfNeeded(students.map((s) => s.uid).toList(), results);

        return Column(
          children: [
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: students.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, index) => _MarkRow(
                  student: students[index],
                  totalMarks: widget.test.totalMarks,
                  controller: _controllers[students[index].uid]!,
                  isAbsent: _absent[students[index].uid] ?? false,
                  enabled: canManage && !_isSubmitting,
                  onAbsentChanged: (value) =>
                      setState(() => _absent[students[index].uid] = value),
                ),
              ),
            ),
            if (canManage)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: AppButton(
                  label: 'Save all marks',
                  isLoading: _isSubmitting,
                  onPressed: _submit,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MarkRow extends StatelessWidget {
  const _MarkRow({
    required this.student,
    required this.totalMarks,
    required this.controller,
    required this.isAbsent,
    required this.enabled,
    required this.onAbsentChanged,
  });

  final StudentProfile student;
  final double totalMarks;
  final TextEditingController controller;
  final bool isAbsent;
  final bool enabled;
  final ValueChanged<bool> onAbsentChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.name),
                  if (student.admissionNumber.isNotEmpty)
                    Text(
                      'Adm. no. ${student.admissionNumber}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            FilterChip(
              label: const Text('Absent'),
              selected: isAbsent,
              onSelected: enabled ? onAbsentChanged : null,
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 80,
              child: TextField(
                controller: controller,
                enabled: enabled && !isAbsent,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: '/ ${totalMarks.toStringAsFixed(0)}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
