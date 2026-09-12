import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../application/homework_controller.dart';

Future<void> showCreateHomeworkDialog(
  BuildContext context, {
  required String batchId,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _CreateHomeworkDialog(batchId: batchId),
  );
}

class _CreateHomeworkDialog extends ConsumerStatefulWidget {
  const _CreateHomeworkDialog({required this.batchId});

  final String batchId;

  @override
  ConsumerState<_CreateHomeworkDialog> createState() =>
      _CreateHomeworkDialogState();
}

class _CreateHomeworkDialogState extends ConsumerState<_CreateHomeworkDialog> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime _date = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isDueDate}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isDueDate ? _dueDate : _date,
      firstDate: DateTime(_date.year - 1),
      lastDate: DateTime(_date.year + 1),
    );
    if (picked == null) return;
    setState(() => isDueDate ? _dueDate = picked : _date = picked);
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    if (_dueDate.isBefore(_date)) {
      setState(
        () => _errorMessage = 'Due date cannot be before the homework date.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(homeworkControllerProvider)
          .createHomework(
            batchId: widget.batchId,
            subject: _subjectController.text,
            date: _date,
            description: _descriptionController.text,
            dueDate: _dueDate,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on HomeworkFailure catch (failure) {
      setState(() => _errorMessage = failure.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New homework'),
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
              title: Text('Date: ${dateKey(_date)}'),
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
