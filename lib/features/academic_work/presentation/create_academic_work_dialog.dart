import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../academics/data/academic_session.dart';
import '../../academics/data/academics_repositories.dart';
import '../../academics/data/school_class.dart';
import '../../academics/data/subject.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/data/user_account.dart';
import '../../batches/data/batch.dart';
import '../../batches/data/batch_repository.dart';
import '../../teacher_assignments/data/teacher_assignment.dart';
import '../../teacher_assignments/data/teacher_assignment_repository.dart';
import '../application/academic_work_controller.dart';
import '../data/academic_work.dart';

/// New homework/assignment creation. Admin sees the full cascading Type
/// -> Academic Session -> Class -> (only matching active batches) ->
/// Subject (only subjects the selected class actually offers, per Set
/// 9's `SchoolClass.subjectIds`) picker (Set 16 spec) - unchanged by Set
/// 23. A signed-in teacher instead picks ONE of their own active
/// `TeacherAssignment`s (Set 22/23) - a single dropdown that fully
/// determines session/class/batch/subject at once, so a teacher can never
/// type or combine a session/class/batch/subject their assignment doesn't
/// cover (Set 23 section 6: "use assignment-derived selection... do not
/// allow the teacher to manually type these relationships"). Both paths
/// call the identical `AcademicWorkController.create` - one write path,
/// not two.
Future<void> showCreateAcademicWorkDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const _CreateAcademicWorkDialog(),
  );
}

class _CreateAcademicWorkDialogState
    extends ConsumerState<_CreateAcademicWorkDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  AcademicWorkType _type = AcademicWorkType.homework;
  String? _sessionId;
  String? _classId;
  String? _batchId;
  String? _subjectId;
  String? _selectedAssignmentId;
  DateTime _assignedDate = DateTime.now();
  DateTime _dueDate = DateTime.now();
  AcademicWorkStatus _status = AcademicWorkStatus.published;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickAssignedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _assignedDate,
      firstDate: DateTime(_assignedDate.year - 1),
      lastDate: DateTime(_assignedDate.year + 1),
    );
    if (picked != null) setState(() => _assignedDate = picked);
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate.isBefore(_assignedDate) ? _assignedDate : _dueDate,
      firstDate: _assignedDate,
      lastDate: DateTime(_assignedDate.year + 1),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _submit(String subjectName) async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    if (_sessionId == null || _classId == null || _batchId == null) {
      setState(
        () => _errorMessage = 'Select an academic session, class and batch.',
      );
      return;
    }
    if (_subjectId == null) {
      setState(() => _errorMessage = 'Select a subject.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(academicWorkControllerProvider)
          .create(
            type: _type,
            academicSessionId: _sessionId!,
            classId: _classId!,
            batchId: _batchId!,
            subjectId: _subjectId!,
            subjectName: subjectName,
            title: _titleController.text,
            description: _descriptionController.text,
            assignedDate: _assignedDate,
            dueDate: _dueDate,
            status: _status,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on AcademicWorkFailure catch (failure) {
      setState(() => _errorMessage = failure.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _assignmentLabel(
    TeacherAssignment assignment,
    List<AcademicSession> sessions,
    List<SchoolClass> classes,
    List<Batch> batches,
    List<Subject> subjects,
  ) {
    final sessionName = sessions
        .where((s) => s.sessionId == assignment.academicSessionId)
        .firstOrNull
        ?.name;
    final className = classes
        .where((c) => c.classId == assignment.classId)
        .firstOrNull
        ?.name;
    final batchName = batches
        .where((b) => b.batchId == assignment.batchId)
        .firstOrNull
        ?.name;
    final subjectName = subjects
        .where((s) => s.subjectId == assignment.subjectId)
        .firstOrNull
        ?.name;
    return '${className ?? 'Unknown class'} - ${batchName ?? 'Unknown batch'} - '
        '${subjectName ?? 'Unknown subject'}'
        '${sessionName != null ? ' ($sessionName)' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(currentUserAccountProvider).valueOrNull;
    final isTeacher = account?.role == UserRole.teacher;
    final sessionsAsync = ref.watch(allAcademicSessionsProvider);
    final classesAsync = ref.watch(activeSchoolClassesProvider);
    final batchesAsync = ref.watch(activeBatchesProvider);
    final subjectsAsync = ref.watch(activeSubjectsProvider);
    final ownAssignmentsAsync = isTeacher
        ? ref.watch(ownTeacherAssignmentsProvider(account!.uid))
        : null;

    return AlertDialog(
      title: const Text('New homework / assignment'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                DropdownButtonFormField<AcademicWorkType>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Type *'),
                  items: AcademicWorkType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.label),
                        ),
                      )
                      .toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (value) => setState(() => _type = value ?? _type),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (isTeacher)
                  ownAssignmentsAsync!.when(
                    loading: () => const SizedBox.shrink(),
                    error: (error, stackTrace) => const SizedBox.shrink(),
                    data: (assignments) {
                      final active = assignments.where((a) => a.active).toList();
                      if (active.isEmpty) {
                        return Text(
                          'You have no active teaching assignments yet - ask '
                          'an admin to assign you to a class/batch/subject.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        );
                      }
                      return DropdownButtonFormField<String>(
                        initialValue: active.any(
                              (a) => a.assignmentId == _selectedAssignmentId,
                            )
                            ? _selectedAssignmentId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'My class / batch / subject *',
                        ),
                        items: [
                          for (final assignment in active)
                            DropdownMenuItem(
                              value: assignment.assignmentId,
                              child: Text(
                                _assignmentLabel(
                                  assignment,
                                  sessionsAsync.valueOrNull ?? const [],
                                  classesAsync.valueOrNull ?? const [],
                                  batchesAsync.valueOrNull ?? const [],
                                  subjectsAsync.valueOrNull ?? const [],
                                ),
                              ),
                            ),
                        ],
                        onChanged: _isSubmitting
                            ? null
                            : (value) => setState(() {
                                _selectedAssignmentId = value;
                                final assignment = active
                                    .where((a) => a.assignmentId == value)
                                    .firstOrNull;
                                _sessionId = assignment?.academicSessionId;
                                _classId = assignment?.classId;
                                _batchId = assignment?.batchId;
                                _subjectId = assignment?.subjectId;
                              }),
                        validator: (value) =>
                            value == null ? 'Select an assignment' : null,
                      );
                    },
                  )
                else ...[
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
                      onChanged: _isSubmitting
                          ? null
                          : (value) => setState(() {
                              _sessionId = value;
                              _batchId = null;
                            }),
                      validator: (value) =>
                          value == null ? 'Select an academic session' : null,
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
                        for (final schoolClass in classes)
                          DropdownMenuItem(
                            value: schoolClass.classId,
                            child: Text(schoolClass.name),
                          ),
                      ],
                      onChanged: _isSubmitting
                          ? null
                          : (value) => setState(() {
                              _classId = value;
                              _batchId = null;
                              _subjectId = null;
                            }),
                      validator: (value) =>
                          value == null ? 'Select a class' : null,
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
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        );
                      }
                      return DropdownButtonFormField<String>(
                        key: ValueKey('batch-$_sessionId-$_classId'),
                        initialValue:
                            matching.any((b) => b.batchId == _batchId)
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
                        validator: (value) =>
                            value == null ? 'Select a batch' : null,
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  classesAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (error, stackTrace) => const SizedBox.shrink(),
                    data: (classes) {
                      final schoolClass = classes
                          .where((c) => c.classId == _classId)
                          .firstOrNull;
                      final subjects = subjectsAsync.valueOrNull ?? const [];
                      final classSubjects = schoolClass == null
                          ? const <Subject>[]
                          : subjects
                                .where(
                                  (s) => schoolClass.subjectIds.contains(
                                    s.subjectId,
                                  ),
                                )
                                .toList();
                      if (_classId == null) {
                        return const Text('Select a class to see subjects.');
                      }
                      if (classSubjects.isEmpty) {
                        return Text(
                          'No subjects configured for this class.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        );
                      }
                      return DropdownButtonFormField<String>(
                        key: ValueKey('subject-$_classId'),
                        initialValue:
                            classSubjects.any((s) => s.subjectId == _subjectId)
                            ? _subjectId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Subject *',
                        ),
                        items: [
                          for (final subject in classSubjects)
                            DropdownMenuItem(
                              value: subject.subjectId,
                              child: Text(subject.name),
                            ),
                        ],
                        onChanged: _isSubmitting
                            ? null
                            : (value) => setState(() => _subjectId = value),
                        validator: (value) =>
                            value == null ? 'Select a subject' : null,
                      );
                    },
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _titleController,
                  label: 'Title *',
                  enabled: !_isSubmitting,
                  validator: (value) =>
                      Validators.required(value, message: 'Title is required'),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _descriptionController,
                  label: 'Description / instructions (optional)',
                  enabled: !_isSubmitting,
                ),
                const SizedBox(height: AppSpacing.sm),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Assigned date: ${dateKey(_assignedDate)}'),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: _isSubmitting ? null : _pickAssignedDate,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Due date: ${dateKey(_dueDate)}'),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: _isSubmitting ? null : _pickDueDate,
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<AcademicWorkStatus>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    for (final status in [
                      AcademicWorkStatus.draft,
                      AcademicWorkStatus.published,
                    ])
                      DropdownMenuItem(value: status, child: Text(status.label)),
                  ],
                  onChanged: _isSubmitting
                      ? null
                      : (value) => setState(() => _status = value ?? _status),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        AppButton(
          label: 'Create',
          isLoading: _isSubmitting,
          onPressed: () {
            final subjects = subjectsAsync.valueOrNull ?? const [];
            final subjectName = subjects
                    .where((s) => s.subjectId == _subjectId)
                    .firstOrNull
                    ?.name ??
                '';
            _submit(subjectName);
          },
        ),
      ],
    );
  }
}

class _CreateAcademicWorkDialog extends ConsumerStatefulWidget {
  const _CreateAcademicWorkDialog();

  @override
  ConsumerState<_CreateAcademicWorkDialog> createState() =>
      _CreateAcademicWorkDialogState();
}
