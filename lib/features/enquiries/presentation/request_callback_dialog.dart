import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../application/enquiry_controller.dart';

Future<void> showRequestCallbackDialog(BuildContext context) {
  return showDialog<void>(context: context, builder: (context) => const _RequestCallbackDialog());
}

class _RequestCallbackDialog extends ConsumerStatefulWidget {
  const _RequestCallbackDialog();

  @override
  ConsumerState<_RequestCallbackDialog> createState() => _RequestCallbackDialogState();
}

class _RequestCallbackDialogState extends ConsumerState<_RequestCallbackDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();

  bool _isSubmitting = false;
  bool _submitted = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
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
          .read(enquiryControllerProvider)
          .submitCallbackRequest(name: _nameController.text, phone: _phoneController.text, message: _messageController.text);
      if (mounted) setState(() => _submitted = true);
    } on EnquiryFailure catch (failure) {
      setState(() => _errorMessage = failure.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return AlertDialog(
        title: const Text('Thank you'),
        content: const Text("We'll call you back soon."),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
      );
    }

    return AlertDialog(
      title: const Text('Request a callback'),
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
              controller: _nameController,
              label: 'Name',
              enabled: !_isSubmitting,
              validator: (value) => Validators.required(value, message: 'Name is required'),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _phoneController,
              label: 'Phone',
              enabled: !_isSubmitting,
              keyboardType: TextInputType.phone,
              validator: (value) => Validators.required(value, message: 'Phone is required'),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(controller: _messageController, label: 'Message (optional)', enabled: !_isSubmitting),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        AppButton(label: 'Submit', isLoading: _isSubmitting, onPressed: _submit),
      ],
    );
  }
}
