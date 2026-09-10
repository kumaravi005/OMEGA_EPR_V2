import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../application/test_controller.dart';
import '../data/test_definition.dart';

Future<void> showCreateTestDialog(
  BuildContext context, {
  required String batchId,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _CreateTestDialog(batchId: batchId),
  );
}

class _CreateTestDialog extends ConsumerStatefulWidget {
  const _CreateTestDialog({required this.batchId});

  final String batchId;

  @override
  ConsumerState<_CreateTestDialog> createState() => _CreateTestDialogState();
}

class _CreateTestDialogState extends ConsumerState<_CreateTestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subjectController = TextEditingController();
  final _chapterController = TextEditingController();
  final _totalMarksController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime _date = DateTime.now();
  TestType _testType = TestType.objective;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _chapterController.dispose();
    _totalMarksController.dispose();
    _descriptionController.dispose();
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

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(testControllerProvider)
          .createTest(
            batchId: widget.batchId,
            subject: _subjectController.text,
            title: _titleController.text,
            chapterTopic: _chapterController.text,
            date: _date,
            totalMarks: double.parse(_totalMarksController.text),
            testType: _testType,
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
    return AlertDialog(
      title: const Text('New test'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
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
              AppTextField(
                controller: _titleController,
                label: 'Test title',
                enabled: !_isSubmitting,
                validator: (value) =>
                    Validators.required(value, message: 'Title is required'),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _subjectController,
                label: 'Subject',
                enabled: !_isSubmitting,
                validator: (value) =>
                    Validators.required(value, message: 'Subject is required'),
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
                label: 'Total marks',
                enabled: !_isSubmitting,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: _validateTotalMarks,
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
                    : (value) => setState(() => _testType = value ?? _testType),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _descriptionController,
                label: 'Description (optional)',
                enabled: !_isSubmitting,
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
        AppButton(
          label: 'Create',
          isLoading: _isSubmitting,
          onPressed: _submit,
        ),
      ],
    );
  }

  String? _validateTotalMarks(String? value) {
    final requiredError = Validators.required(
      value,
      message: 'Total marks is required',
    );
    if (requiredError != null) return requiredError;
    final parsed = double.tryParse(value!);
    if (parsed == null || parsed <= 0) return 'Enter a valid positive number';
    return null;
  }
}
