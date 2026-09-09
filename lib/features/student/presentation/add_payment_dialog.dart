import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../application/payment_controller.dart';
import '../data/payment.dart';

Future<void> showAddPaymentDialog(BuildContext context, {required String studentUid, required String batchId}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _AddPaymentDialog(studentUid: studentUid, batchId: batchId),
  );
}

class _AddPaymentDialog extends ConsumerStatefulWidget {
  const _AddPaymentDialog({required this.studentUid, required this.batchId});

  final String studentUid;
  final String batchId;

  @override
  ConsumerState<_AddPaymentDialog> createState() => _AddPaymentDialogState();
}

class _AddPaymentDialogState extends ConsumerState<_AddPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _remarkController = TextEditingController();

  DateTime _date = DateTime.now();
  PaymentMode _mode = PaymentMode.cash;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _amountController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 5),
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
          .read(paymentControllerProvider)
          .recordPayment(
            studentUid: widget.studentUid,
            batchId: widget.batchId,
            amount: double.parse(_amountController.text),
            date: _date,
            mode: _mode,
            remark: _remarkController.text.trim().isEmpty ? null : _remarkController.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on PaymentFailure catch (failure) {
      setState(() => _errorMessage = failure.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record payment'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null) ...[
              Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: AppSpacing.sm),
            ],
            AppTextField(
              controller: _amountController,
              label: 'Amount',
              enabled: !_isSubmitting,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: _validateAmount,
            ),
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Date: ${_date.toLocal()}'.split(' ').first),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _isSubmitting ? null : _pickDate,
            ),
            DropdownButtonFormField<PaymentMode>(
              initialValue: _mode,
              decoration: const InputDecoration(labelText: 'Payment mode'),
              items: PaymentMode.values
                  .map((mode) => DropdownMenuItem(value: mode, child: Text(mode.label)))
                  .toList(),
              onChanged: _isSubmitting ? null : (value) => setState(() => _mode = value ?? _mode),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(controller: _remarkController, label: 'Remark (optional)', enabled: !_isSubmitting),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        AppButton(label: 'Save', isLoading: _isSubmitting, onPressed: _submit),
      ],
    );
  }

  String? _validateAmount(String? value) {
    final requiredError = Validators.required(value, message: 'Amount is required');
    if (requiredError != null) return requiredError;
    final parsed = double.tryParse(value!);
    if (parsed == null || parsed <= 0) return 'Enter a valid amount';
    return null;
  }
}
