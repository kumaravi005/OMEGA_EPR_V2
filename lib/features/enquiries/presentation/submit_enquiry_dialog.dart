import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../application/enquiry_controller.dart';

Future<void> showSubmitEnquiryDialog(BuildContext context) {
  return showDialog<void>(context: context, builder: (context) => const _SubmitEnquiryDialog());
}

class _SubmitEnquiryDialog extends ConsumerStatefulWidget {
  const _SubmitEnquiryDialog();

  @override
  ConsumerState<_SubmitEnquiryDialog> createState() => _SubmitEnquiryDialogState();
}

class _SubmitEnquiryDialogState extends ConsumerState<_SubmitEnquiryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _guardianController = TextEditingController();
  final _classController = TextEditingController();
  final _boardController = TextEditingController();
  final _primaryPhoneController = TextEditingController();
  final _secondaryPhoneController = TextEditingController();
  final _messageController = TextEditingController();

  bool _isSubmitting = false;
  bool _submitted = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _guardianController.dispose();
    _classController.dispose();
    _boardController.dispose();
    _primaryPhoneController.dispose();
    _secondaryPhoneController.dispose();
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
          .submitEnquiry(
            name: _nameController.text,
            guardianName: _guardianController.text,
            className: _classController.text,
            board: _boardController.text,
            primaryPhone: _primaryPhoneController.text,
            secondaryPhone: _secondaryPhoneController.text,
            message: _messageController.text,
          );
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
        content: const Text('Your enquiry has been submitted. Our team will contact you soon.'),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
      );
    }

    return AlertDialog(
      title: const Text('Admission enquiry'),
      content: SingleChildScrollView(
        child: Form(
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
                label: 'Student name',
                enabled: !_isSubmitting,
                validator: (value) => Validators.required(value, message: 'Name is required'),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(controller: _guardianController, label: "Father's/guardian's name (optional)", enabled: !_isSubmitting),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(controller: _classController, label: 'Class (optional)', enabled: !_isSubmitting),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(controller: _boardController, label: 'Board (optional)', enabled: !_isSubmitting),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _primaryPhoneController,
                label: 'Primary phone',
                enabled: !_isSubmitting,
                keyboardType: TextInputType.phone,
                validator: (value) => Validators.required(value, message: 'Primary phone is required'),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _secondaryPhoneController,
                label: 'Secondary phone (optional)',
                enabled: !_isSubmitting,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(controller: _messageController, label: 'Message (optional)', enabled: !_isSubmitting),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        AppButton(label: 'Submit', isLoading: _isSubmitting, onPressed: _submit),
      ],
    );
  }
}
