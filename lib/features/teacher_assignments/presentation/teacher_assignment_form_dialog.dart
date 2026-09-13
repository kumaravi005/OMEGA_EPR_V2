import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../academics/data/academics_repositories.dart';
import '../../batches/data/batch_repository.dart';
import '../../teacher/data/teacher_repository.dart';
import '../application/teacher_assignment_controller.dart';
import '../data/teacher_assignment_repository.dart';

/// Admin's "Add Assignment" dialog (Set 22 section 9) - a strict
/// Teacher -> Session -> Class -> Batch -> Subject cascade. There is no
/// edit mode: teacherId/session/class/batch/subject together ARE an
/// assignment's identity (see `TeacherAssignment.idFor`), so changing any
/// of them after creation would mean a different assignment, not an edit
/// of this one - the only thing ever mutated afterward is active/inactive
/// (see the list screen's Activate/Deactivate action).
void showTeacherAssignmentFormDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => const _TeacherAssignmentFormDialog(),
  );
}

class _TeacherAssignmentFormDialog extends ConsumerStatefulWidget {
  const _TeacherAssignmentFormDialog();

  @override
  ConsumerState<_TeacherAssignmentFormDialog> createState() =>
      _TeacherAssignmentFormDialogState();
}

class _TeacherAssignmentFormDialogState
    extends ConsumerState<_TeacherAssignmentFormDialog> {
  String? _teacherId;
  String? _sessionId;
  String? _classId;
  String? _batchId;
  String? _subjectId;
  bool _isSubmitting = false;
  String? _errorMessage;

  void _onTeacherChanged(String? value) {
    setState(() {
      _teacherId = value;
      _subjectId = null; // revalidate: capability may differ (section 9)
    });
  }

  void _onSessionChanged(String? value) {
    setState(() {
      _sessionId = value;
      _batchId = null;
    });
  }

  void _onClassChanged(String? value) {
    setState(() {
      _classId = value;
      _batchId = null;
      _subjectId = null;
    });
  }

  Future<void> _submit() async {
    if (_teacherId == null ||
        _sessionId == null ||
        _classId == null ||
        _batchId == null ||
        _subjectId == null) {
      setState(
        () => _errorMessage = 'Select a teacher, session, class, batch and subject.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final existing = ref.read(allTeacherAssignmentsProvider).valueOrNull ??
          const [];
      if (isDuplicateAssignment(
        existing,
        teacherId: _teacherId!,
        academicSessionId: _sessionId!,
        batchId: _batchId!,
        subjectId: _subjectId!,
      )) {
        setState(
          () => _errorMessage =
              'This teacher already has an assignment for this session, '
              'batch and subject.',
        );
        return;
      }

      await ref.read(teacherAssignmentControllerProvider).createAssignment(
            teacherId: _teacherId!,
            academicSessionId: _sessionId!,
            classId: _classId!,
            batchId: _batchId!,
            subjectId: _subjectId!,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on TeacherAssignmentFailure catch (failure) {
      setState(() => _errorMessage = failure.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teachersAsync = ref.watch(activeTeachersProvider);
    final sessionsAsync = ref.watch(allAcademicSessionsProvider);
    final classesAsync = ref.watch(activeSchoolClassesProvider);
    final batchesAsync = ref.watch(activeBatchesProvider);
    final subjectsAsync = ref.watch(allSubjectsProvider);

    final teacher = (teachersAsync.valueOrNull ?? const [])
        .where((t) => t.uid == _teacherId)
        .firstOrNull;
    final schoolClass = (classesAsync.valueOrNull ?? const [])
        .where((c) => c.classId == _classId)
        .firstOrNull;
    final subjectOptions = subjectOptionsForAssignment(
      schoolClass: schoolClass,
      teacher: teacher,
      allSubjects: subjectsAsync.valueOrNull ?? const [],
    );

    return AlertDialog(
      title: const Text('Add assignment'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              teachersAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (error, stackTrace) => const SizedBox.shrink(),
                data: (teachers) => DropdownButtonFormField<String>(
                  initialValue: _teacherId,
                  decoration: const InputDecoration(labelText: 'Teacher *'),
                  items: [
                    for (final t in teachers)
                      DropdownMenuItem(value: t.uid, child: Text(t.name)),
                  ],
                  onChanged: _isSubmitting ? null : _onTeacherChanged,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              sessionsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (error, stackTrace) => const SizedBox.shrink(),
                data: (sessions) => DropdownButtonFormField<String>(
                  initialValue: _sessionId,
                  decoration: const InputDecoration(
                    labelText: 'Academic session *',
                  ),
                  items: [
                    for (final session in sessions)
                      DropdownMenuItem(
                        value: session.sessionId,
                        child: Text(session.name),
                      ),
                  ],
                  onChanged: _isSubmitting ? null : _onSessionChanged,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              classesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (error, stackTrace) => const SizedBox.shrink(),
                data: (classes) => DropdownButtonFormField<String>(
                  initialValue: _classId,
                  decoration: const InputDecoration(labelText: 'Class *'),
                  items: [
                    for (final c in classes)
                      DropdownMenuItem(value: c.classId, child: Text(c.name)),
                  ],
                  onChanged: _isSubmitting ? null : _onClassChanged,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              batchesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (error, stackTrace) => const SizedBox.shrink(),
                data: (batches) {
                  final matching = batchesForSessionAndClass(
                    batches,
                    academicSessionId: _sessionId,
                    classId: _classId,
                  );
                  if (_sessionId == null || _classId == null) {
                    return const Text(
                      'Select a session and class to see matching batches.',
                    );
                  }
                  if (matching.isEmpty) {
                    return Text(
                      'No active batches for this session/class.',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    );
                  }
                  return DropdownButtonFormField<String>(
                    key: ValueKey('batch-$_sessionId-$_classId'),
                    initialValue: matching.any((b) => b.batchId == _batchId)
                        ? _batchId
                        : null,
                    decoration: const InputDecoration(labelText: 'Batch *'),
                    items: [
                      for (final batch in matching)
                        DropdownMenuItem(
                          value: batch.batchId,
                          child: Text(batch.name),
                        ),
                    ],
                    onChanged: _isSubmitting
                        ? null
                        : (value) => setState(() => _batchId = value),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Builder(
                builder: (context) {
                  if (_teacherId == null || _classId == null) {
                    return const Text(
                      'Select a teacher and class to see eligible subjects.',
                    );
                  }
                  if (subjectOptions.isEmpty) {
                    return Text(
                      'This teacher is not configured to teach any subject '
                      'this class offers.',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    );
                  }
                  return DropdownButtonFormField<String>(
                    key: ValueKey('subject-$_teacherId-$_classId'),
                    initialValue:
                        subjectOptions.any((s) => s.subjectId == _subjectId)
                        ? _subjectId
                        : null,
                    decoration: const InputDecoration(labelText: 'Subject *'),
                    items: [
                      for (final subject in subjectOptions)
                        DropdownMenuItem(
                          value: subject.subjectId,
                          child: Text(subject.name),
                        ),
                    ],
                    onChanged: _isSubmitting
                        ? null
                        : (value) => setState(() => _subjectId = value),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        AppButton(label: 'Save', isLoading: _isSubmitting, onPressed: _submit),
      ],
    );
  }
}
