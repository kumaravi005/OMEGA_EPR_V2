import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../batches/data/installment_schedule_item.dart';

/// Collects one row of a student's installment schedule (label, amount,
/// due date) - shared by the admission form and the batch-transfer
/// dialog so the two don't duplicate this input flow.
Future<InstallmentScheduleItem?> showInstallmentEntryDialog(
  BuildContext context,
) {
  return showDialog<InstallmentScheduleItem>(
    context: context,
    builder: (context) => const _InstallmentEntryDialog(),
  );
}

class _InstallmentEntryDialog extends StatefulWidget {
  const _InstallmentEntryDialog();

  @override
  State<_InstallmentEntryDialog> createState() =>
      _InstallmentEntryDialogState();
}

class _InstallmentEntryDialogState extends State<_InstallmentEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime? _dueDate;
  String? _dateError;

  @override
  void dispose() {
    _labelController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  void _submit() {
    final form = _formKey.currentState;
    setState(() => _dateError = _dueDate == null ? 'Select a due date' : null);
    if (form == null || !form.validate() || _dueDate == null) return;

    Navigator.of(context).pop(
      InstallmentScheduleItem(
        label: _labelController.text.trim(),
        amount: double.parse(_amountController.text),
        dueDate: _dueDate!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add installment'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _labelController,
                label: 'Label',
                hintText: 'e.g. Admission, 1st installment',
                validator: (value) =>
                    Validators.required(value, message: 'Label is required'),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _amountController,
                label: 'Amount',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) => Validators.amount(
                  value,
                  label: 'Amount',
                  allowZero: false,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _dueDate == null
                      ? 'Due date'
                      : 'Due date: ${_dueDate!.toLocal()}'.split(' ').first,
                ),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _pickDueDate,
              ),
              if (_dateError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _dateError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        AppButton(label: 'Add', onPressed: _submit),
      ],
    );
  }
}
