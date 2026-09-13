import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../academics/data/academics_repositories.dart';
import '../../academics/data/subject.dart';
import '../../batches/data/batch_repository.dart';
import '../application/test_controller.dart';
import '../data/test_definition.dart';

/// New-test creation, cascading Academic Session -> Class -> (only
/// matching active batches) -> Subject (only subjects the selected
/// class actually offers, per Set 9's `SchoolClass.subjectIds`) -> test
/// details (Set 14 spec).
Future<void> showCreateTestDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const _CreateTestDialog(),
  );
}

class _CreateTestDialogState extends ConsumerState<_CreateTestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _chapterController = TextEditingController();
  final _totalMarksController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _otherTypeLabelController = TextEditingController();

  String? _sessionId;
  String? _classId;
  String? _batchId;
  String? _subjectId;
  DateTime _date = DateTime.now();
  TestType _testType = TestType.unitTest;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _chapterController.dispose();
    _totalMarksController.dispose();
    _descriptionController.dispose();
    _otherTypeLabelController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
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
          .read(testControllerProvider)
          .createTest(
            batchId: _batchId!,
            academicSessionId: _sessionId!,
            classId: _classId!,
            subjectId: _subjectId!,
            subjectName: subjectName,
            title: _titleController.text,
            chapterTopic: _chapterController.text,
            date: _date,
            totalMarks: double.parse(_totalMarksController.text),
            testType: _testType,
            otherTestTypeLabel: _otherTypeLabelController.text,
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on TestActionFailure catch (failure) {
      setState(() => _errorMessage = failure.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(allAcademicSessionsProvider);
    final classesAsync = ref.watch(activeSchoolClassesProvider);
    final batchesAsync = ref.watch(activeBatchesProvider);
    final subjectsAsync = ref.watch(activeSubjectsProvider);

    return AlertDialog(
      title: const Text('New test'),
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
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _titleController,
                  label: 'Test title',
                  enabled: !_isSubmitting,
                  validator: (value) =>
                      Validators.required(value, message: 'Title is required'),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _chapterController,
                  label: 'Chapter / topic',
                  enabled: !_isSubmitting,
                  validator: (value) => Validators.required(
                    value,
                    message: 'Chapter/topic is required',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Date: ${dateKey(_date)}'),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: _isSubmitting ? null : _pickDate,
                ),
                AppTextField(
                  controller: _totalMarksController,
                  label: 'Maximum marks',
                  enabled: !_isSubmitting,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) => Validators.amount(
                    value,
                    label: 'Maximum marks',
                    allowZero: false,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<TestType>(
                  initialValue: _testType,
                  decoration: const InputDecoration(labelText: 'Test type'),
                  items: TestType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.label),
                        ),
                      )
                      .toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (value) =>
                            setState(() => _testType = value ?? _testType),
                ),
                if (_testType == TestType.other) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: _otherTypeLabelController,
                    label: 'Test type name (since "Other" was selected)',
                    enabled: !_isSubmitting,
                    validator: (value) => Validators.required(
                      value,
                      message: 'Enter a test type name',
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _descriptionController,
                  label: 'Description / instructions (optional)',
                  enabled: !_isSubmitting,
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

class _CreateTestDialog extends ConsumerStatefulWidget {
  const _CreateTestDialog();

  @override
  ConsumerState<_CreateTestDialog> createState() => _CreateTestDialogState();
}
