import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../application/fee_payment_controller.dart';
import '../data/fee_payment.dart';

/// A controlled reversal, not a delete or a silent amount edit (Set 19
/// section 9) - the original [payment] is preserved unchanged; this only
/// ever sets its status/reversedBy/reversedAt/reversalReason.
Future<void> showReversePaymentDialog(BuildContext context, FeePayment payment) {
  return showDialog<void>(
    context: context,
    builder: (context) => _ReversePaymentDialog(payment: payment),
  );
}

class _ReversePaymentDialog extends ConsumerStatefulWidget {
  const _ReversePaymentDialog({required this.payment});

  final FeePayment payment;

  @override
  ConsumerState<_ReversePaymentDialog> createState() => _ReversePaymentDialogState();
}

class _ReversePaymentDialogState extends ConsumerState<_ReversePaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
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
          .read(feePaymentControllerProvider)
          .reversePayment(widget.payment, _reasonController.text);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on FeePaymentFailure catch (failure) {
      setState(() => _errorMessage = failure.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reverse payment'),
      content: SizedBox(
        width: 380,
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
              Text(
                '${widget.payment.paymentNumber} - ₹${widget.payment.amount.toStringAsFixed(0)} '
                '(${widget.payment.mode.label})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'This does not delete the payment - it stays in history, marked '
                'reversed, and is excluded from total paid.',
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _reasonController,
                label: 'Reason for reversal',
                enabled: !_isSubmitting,
                validator: (value) =>
                    Validators.required(value, message: 'A reason is required'),
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
        AppButton(label: 'Reverse payment', isLoading: _isSubmitting, onPressed: _submit),
      ],
    );
  }
}
