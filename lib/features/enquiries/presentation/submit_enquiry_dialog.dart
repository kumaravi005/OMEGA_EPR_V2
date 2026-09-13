import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../academics/data/academics_repositories.dart';
import '../application/enquiry_controller.dart';

Future<void> showSubmitEnquiryDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const _SubmitEnquiryDialog(),
  );
}

class _SubmitEnquiryDialog extends ConsumerStatefulWidget {
  const _SubmitEnquiryDialog();

  @override
  ConsumerState<_SubmitEnquiryDialog> createState() =>
      _SubmitEnquiryDialogState();
}

class _SubmitEnquiryDialogState extends ConsumerState<_SubmitEnquiryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _guardianController = TextEditingController();
  final _boardCustomController = TextEditingController();
  final _primaryPhoneController = TextEditingController();
  final _secondaryPhoneController = TextEditingController();
  final _messageController = TextEditingController();

  String? _classId;
  String? _boardId;

  bool _isSubmitting = false;
  bool _submitted = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _guardianController.dispose();
    _boardCustomController.dispose();
    _primaryPhoneController.dispose();
    _secondaryPhoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit(String className, String boardName) async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    if (_classId == null) {
      setState(() => _errorMessage = 'Please select a class.');
      return;
    }
    if (_boardId == null) {
      setState(() => _errorMessage = 'Please select a board.');
      return;
    }

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
            classId: _classId!,
            className: className,
            boardId: _boardId!,
            boardName: boardName,
            boardCustomText: _boardCustomController.text,
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
        content: const Text(
          'Your enquiry has been submitted successfully. Our team will contact you soon.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    }

    final classesAsync = ref.watch(activeSchoolClassesProvider);
    final boardsAsync = ref.watch(activeBoardsProvider);
    final boards = boardsAsync.valueOrNull ?? const [];
    final selectedBoard = boards.where((b) => b.boardId == _boardId).firstOrNull;
    final isOthersBoard = selectedBoard?.name == 'Others';

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
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              AppTextField(
                controller: _nameController,
                label: 'Student name',
                enabled: !_isSubmitting,
                validator: (value) =>
                    Validators.required(value, message: 'Name is required'),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _guardianController,
                label: "Father's/guardian's name (optional)",
                enabled: !_isSubmitting,
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
                      : (value) => setState(() => _classId = value),
                  validator: (value) => value == null ? 'Select a class' : null,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              boardsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (error, stackTrace) => const SizedBox.shrink(),
                data: (boardList) => DropdownButtonFormField<String>(
                  initialValue: _boardId,
                  decoration: const InputDecoration(labelText: 'Board *'),
                  items: [
                    for (final board in boardList)
                      DropdownMenuItem(value: board.boardId, child: Text(board.name)),
                  ],
                  onChanged: _isSubmitting
                      ? null
                      : (value) => setState(() => _boardId = value),
                  validator: (value) => value == null ? 'Select a board' : null,
                ),
              ),
              if (isOthersBoard) ...[
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _boardCustomController,
                  label: 'Board name (since "Others" was selected)',
                  enabled: !_isSubmitting,
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _primaryPhoneController,
                label: 'Primary phone',
                enabled: !_isSubmitting,
                keyboardType: TextInputType.phone,
                validator: (value) =>
                    Validators.phone(value, label: 'Primary phone'),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _secondaryPhoneController,
                label: 'Secondary phone (optional)',
                enabled: !_isSubmitting,
                keyboardType: TextInputType.phone,
                validator: (value) => Validators.phone(
                  value,
                  isRequired: false,
                  label: 'Secondary phone',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _messageController,
                label: 'Message (optional)',
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
          label: 'Submit',
          isLoading: _isSubmitting,
          onPressed: () {
            final classes = classesAsync.valueOrNull ?? const [];
            final className = classes
                    .where((c) => c.classId == _classId)
                    .firstOrNull
                    ?.name ??
                '';
            final boardName = selectedBoard?.name ?? '';
            _submit(className, boardName);
          },
        ),
      ],
    );
  }
}
