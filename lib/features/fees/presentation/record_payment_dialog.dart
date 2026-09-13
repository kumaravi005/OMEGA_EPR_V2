import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../student/data/payment.dart';
import '../../student/data/student_admission.dart';
import '../../student/data/student_profile.dart';
import '../application/fee_payment_controller.dart';

/// Record Payment flow (Set 19 section 7): amount -> date -> mode ->
/// reference if applicable -> remark -> optional installment -> a live
/// Current Final Fee / Total Paid / Current Due / This Payment /
/// Remaining Due review, so admin sees the financial effect before
/// confirming. [currentTotalPaid] is the figure already shown on the
/// student fee details screen this dialog was opened from (combined
/// across the new ledger and any legacy history) - passed in rather than
/// re-fetched, avoiding a redundant read for a value already on screen.
Future<void> showRecordPaymentDialog(
  BuildContext context, {
  required StudentProfile student,
  required StudentAdmission admission,
  required double currentTotalPaid,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _RecordPaymentDialog(
      student: student,
      admission: admission,
      currentTotalPaid: currentTotalPaid,
    ),
  );
}

class _RecordPaymentDialog extends ConsumerStatefulWidget {
  const _RecordPaymentDialog({
    required this.student,
    required this.admission,
    required this.currentTotalPaid,
  });

  final StudentProfile student;
  final StudentAdmission admission;
  final double currentTotalPaid;

  @override
  ConsumerState<_RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends ConsumerState<_RecordPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _remarkController = TextEditingController();

  DateTime _date = DateTime.now();
  PaymentMode _mode = PaymentMode.cash;
  int? _installmentIndex;
  bool _isSubmitting = false;
  String? _errorMessage;

  double get _currentDue => widget.admission.finalFee - widget.currentTotalPaid;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
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

    final installments = widget.admission.installments;
    final selectedInstallment =
        _installmentIndex != null && _installmentIndex! < installments.length
        ? installments[_installmentIndex!]
        : null;

    try {
      await ref.read(feePaymentControllerProvider).recordPayment(
        student: widget.student,
        admission: widget.admission,
        amount: double.parse(_amountController.text),
        paymentDate: _date,
        mode: _mode,
        referenceNumber: _referenceController.text,
        remark: _remarkController.text,
        installmentIndex: _installmentIndex,
        installmentLabel: selectedInstallment?.label,
        currentDue: _currentDue,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on FeePaymentFailure catch (failure) {
      setState(() => _errorMessage = failure.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _validateAmount(String? value) {
    final requiredError = Validators.required(value, message: 'Amount is required');
    if (requiredError != null) return requiredError;
    final parsed = double.tryParse(value!);
    if (parsed == null || parsed <= 0) return 'Enter a valid amount';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final remainingAfter = _currentDue - amount;
    final installments = widget.admission.installments;

    return AlertDialog(
      title: const Text('Record payment'),
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
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
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
                  title: Text('Payment date: ${dateKey(_date)}'),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: _isSubmitting ? null : _pickDate,
                ),
                DropdownButtonFormField<PaymentMode>(
                  initialValue: _mode,
                  decoration: const InputDecoration(labelText: 'Payment mode'),
                  items: PaymentMode.values
                      .map((mode) => DropdownMenuItem(value: mode, child: Text(mode.label)))
                      .toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (value) => setState(() => _mode = value ?? _mode),
                ),
                if (_mode != PaymentMode.cash) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: _referenceController,
                    label: 'Reference / transaction number (optional)',
                    enabled: !_isSubmitting,
                  ),
                ],
                if (installments.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<int?>(
                    initialValue: _installmentIndex,
                    decoration: const InputDecoration(
                      labelText: 'Apply to installment (optional)',
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Overall outstanding balance'),
                      ),
                      for (var i = 0; i < installments.length; i++)
                        DropdownMenuItem<int?>(
                          value: i,
                          child: Text(
                            '${installments[i].label} - ₹${installments[i].amount.toStringAsFixed(0)}',
                          ),
                        ),
                    ],
                    onChanged: _isSubmitting
                        ? null
                        : (value) => setState(() => _installmentIndex = value),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _remarkController,
                  label: 'Remark (optional)',
                  enabled: !_isSubmitting,
                ),
                const SizedBox(height: AppSpacing.md),
                const Divider(),
                _ReviewRow('Current final fee', widget.admission.finalFee),
                _ReviewRow('Total paid so far', widget.currentTotalPaid),
                _ReviewRow('Current due', _currentDue),
                _ReviewRow('This payment', amount),
                _ReviewRow(
                  'Remaining due after this payment',
                  remainingAfter,
                  emphasize: true,
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
        AppButton(label: 'Confirm & save', isLoading: _isSubmitting, onPressed: _submit),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow(this.label, this.amount, {this.emphasize = false});

  final String label;
  final double amount;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: emphasize ? FontWeight.bold : FontWeight.w600,
              color: emphasize && amount > 0
                  ? Theme.of(context).colorScheme.error
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
