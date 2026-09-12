import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../application/assignment_controller.dart';

Future<void> showCreateAssignmentDialog(
  BuildContext context, {
  required String batchId,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _CreateAssignmentDialog(batchId: batchId),
  );
}

class _CreateAssignmentDialog extends ConsumerStatefulWidget {
  const _CreateAssignmentDialog({required this.batchId});

  final String batchId;

  @override
  ConsumerState<_CreateAssignmentDialog> createState() =>
      _CreateAssignmentDialogState();
}

class _CreateAssignmentDialogState
    extends ConsumerState<_CreateAssignmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime _assignedDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _subjectController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isDueDate}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isDueDate ? _dueDate : _assignedDate,
      firstDate: DateTime(_assignedDate.year - 1),
      lastDate: DateTime(_assignedDate.year + 1),
    );
    if (picked == null) return;
    setState(() => isDueDate ? _dueDate = picked : _assignedDate = picked);
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    if (_dueDate.isBefore(_assignedDate)) {
      setState(
        () => _errorMessage = 'Due date cannot be before the assigned date.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(assignmentControllerProvider)
          .createAssignment(
            batchId: widget.batchId,
            subject: _subjectController.text,
            title: _titleController.text,
            description: _descriptionController.text,
            assignedDate: _assignedDate,
            dueDate: _dueDate,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on AssignmentFailure catch (failure) {
      setState(() => _errorMessage = failure.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New assignment'),
      content: Form(
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
              label: 'Title',
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
              controller: _descriptionController,
              label: 'Description',
              enabled: !_isSubmitting,
              validator: (value) => Validators.required(
                value,
                message: 'Description is required',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Assigned date: ${dateKey(_assignedDate)}'),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _isSubmitting ? null : () => _pickDate(isDueDate: false),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Due date: ${dateKey(_dueDate)}'),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _isSubmitting ? null : () => _pickDate(isDueDate: true),
            ),
          ],
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
}
