import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/gender.dart';
import '../../batches/data/batch.dart';
import '../../batches/data/batch_repository.dart';
import '../application/student_form_controller.dart';
import '../data/student_profile.dart';
import '../data/student_repository.dart';

/// Admit a new student, or edit an existing one. Pass [studentUid] to
/// edit; omit it to admit a new student.
class StudentFormScreen extends ConsumerWidget {
  const StudentFormScreen({super.key, this.studentUid});

  final String? studentUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchesAsync = ref.watch(activeBatchesProvider);

    return Scaffold(
      body: SafeArea(
        child: batchesAsync.when(
          loading: () => const LoadingView(message: 'Loading batches...'),
          error: (error, stackTrace) =>
              ErrorView(message: 'Could not load batches.\n$error'),
          data: (batches) {
            if (studentUid == null) {
              return _StudentForm(existing: null, batches: batches);
            }
            final studentsAsync = ref.watch(allStudentsProvider);
            return studentsAsync.when(
              loading: () => const LoadingView(),
              error: (error, stackTrace) =>
                  ErrorView(message: 'Could not load student.\n$error'),
              data: (students) {
                final existing = students
                    .where((s) => s.uid == studentUid)
                    .firstOrNull;
                if (existing == null) {
                  return const ErrorView(message: 'Student not found.');
                }
                return _StudentForm(existing: existing, batches: batches);
              },
            );
          },
        ),
      ),
    );
  }
}

class _StudentForm extends ConsumerStatefulWidget {
  const _StudentForm({required this.existing, required this.batches});

  final StudentProfile? existing;
  final List<Batch> batches;

  @override
  ConsumerState<_StudentForm> createState() => _StudentFormState();
}

class _StudentFormState extends ConsumerState<_StudentForm> {
  final _formKey = GlobalKey<FormState>();
  late final _accountIdController = TextEditingController(
    text: widget.existing?.accountId ?? '',
  );
  final _passwordController = TextEditingController();
  late final _nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final _fatherNameController = TextEditingController(
    text: widget.existing?.fatherName ?? '',
  );
  late final _addressController = TextEditingController(
    text: widget.existing?.address ?? '',
  );
  late final _classController = TextEditingController(
    text: widget.existing?.className ?? '',
  );
  late final _boardController = TextEditingController(
    text: widget.existing?.board ?? '',
  );
  late final _sessionController = TextEditingController(
    text: widget.existing?.academicSession ?? '',
  );
  late final _primaryMobileController = TextEditingController(
    text: widget.existing?.primaryMobile ?? '',
  );
  late final _secondaryMobileController = TextEditingController(
    text: widget.existing?.secondaryMobile ?? '',
  );
  late final _finalFeeController = TextEditingController(
    text: widget.existing?.finalFee.toStringAsFixed(0) ?? '',
  );
  late final _feeReasonController = TextEditingController(
    text: widget.existing?.feeReason ?? '',
  );

  DateTime? _dateOfBirth;
  Gender _gender = Gender.male;
  String? _selectedBatchId;
  double _standardFee = 0;
  PaymentPlan _paymentPlan = PaymentPlan.monthly;

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _dateOfBirth = widget.existing?.dateOfBirth;
    _gender = widget.existing?.gender ?? Gender.male;
    _paymentPlan = widget.existing?.paymentPlan ?? PaymentPlan.monthly;
    _standardFee = widget.existing?.standardFee ?? 0;
    _selectedBatchId =
        widget.existing?.batchId ??
        (widget.batches.isNotEmpty ? widget.batches.first.batchId : null);
    if (!_isEditing) _recomputeStandardFee();
    _finalFeeController.addListener(_onFinalFeeChanged);
  }

  /// The standard fee depends on BOTH the selected batch and the chosen
  /// payment plan - a batch has separate monthly/installment fees (see
  /// [Batch]), so switching either one recomputes it.
  void _recomputeStandardFee() {
    final batch = widget.batches
        .where((b) => b.batchId == _selectedBatchId)
        .firstOrNull;
    if (batch == null) return;
    _standardFee = batch.standardFeeFor(
      isInstallment: _paymentPlan == PaymentPlan.installment,
    );
    // Auto-populate the final fee to match the standard fee - admin can
    // still adjust it below (that's the discount workflow).
    _finalFeeController.text = _standardFee.toStringAsFixed(0);
  }

  void _onFinalFeeChanged() => setState(() {});

  @override
  void dispose() {
    _accountIdController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _fatherNameController.dispose();
    _addressController.dispose();
    _classController.dispose();
    _boardController.dispose();
    _sessionController.dispose();
    _primaryMobileController.dispose();
    _secondaryMobileController.dispose();
    _finalFeeController.removeListener(_onFinalFeeChanged);
    _finalFeeController.dispose();
    _feeReasonController.dispose();
    super.dispose();
  }

  void _onBatchSelected(String? batchId) {
    if (batchId == null) return;
    setState(() {
      _selectedBatchId = batchId;
      if (!_isEditing) _recomputeStandardFee();
    });
  }

  void _onPaymentPlanSelected(PaymentPlan? plan) {
    if (plan == null) return;
    setState(() {
      _paymentPlan = plan;
      if (!_isEditing) _recomputeStandardFee();
    });
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 10),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    if (_dateOfBirth == null) {
      setState(() => _errorMessage = 'Date of birth is required.');
      return;
    }
    if (_selectedBatchId == null) {
      setState(() => _errorMessage = 'Select a batch.');
      return;
    }

    final finalFee = double.parse(_finalFeeController.text);
    if (finalFee != _standardFee && _feeReasonController.text.trim().isEmpty) {
      setState(
        () => _errorMessage =
            'A reason is required when the final fee differs from the standard fee.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final controller = ref.read(studentFormControllerProvider);
      final secondaryMobile = _secondaryMobileController.text.trim().isEmpty
          ? null
          : _secondaryMobileController.text;
      final feeReason = _feeReasonController.text.trim().isEmpty
          ? null
          : _feeReasonController.text;

      if (_isEditing) {
        await controller.updateStudent(
          existing: widget.existing!,
          name: _nameController.text,
          fatherName: _fatherNameController.text,
          dateOfBirth: _dateOfBirth!,
          gender: _gender,
          address: _addressController.text,
          className: _classController.text,
          board: _boardController.text,
          batchId: _selectedBatchId!,
          academicSession: _sessionController.text,
          primaryMobile: _primaryMobileController.text,
          secondaryMobile: secondaryMobile,
          standardFee: _standardFee,
          finalFee: finalFee,
          feeReason: feeReason,
          paymentPlan: _paymentPlan,
        );
      } else {
        await controller.admitStudent(
          accountId: _accountIdController.text,
          password: _passwordController.text,
          name: _nameController.text,
          fatherName: _fatherNameController.text,
          dateOfBirth: _dateOfBirth!,
          gender: _gender,
          address: _addressController.text,
          className: _classController.text,
          board: _boardController.text,
          batchId: _selectedBatchId!,
          academicSession: _sessionController.text,
          primaryMobile: _primaryMobileController.text,
          secondaryMobile: secondaryMobile,
          standardFee: _standardFee,
          finalFee: finalFee,
          feeReason: feeReason,
          paymentPlan: _paymentPlan,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on StudentFormFailure catch (failure) {
      setState(() => _errorMessage = failure.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final discount =
        _standardFee -
        (double.tryParse(_finalFeeController.text) ?? _standardFee);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit student' : 'Admit student'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null) ...[
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    Text(
                      'Login credentials',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      controller: _accountIdController,
                      label: 'Account ID',
                      enabled: !_isSubmitting && !_isEditing,
                      validator: _isEditing ? null : _validateAccountId,
                    ),
                    if (!_isEditing) ...[
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        controller: _passwordController,
                        label: 'Password',
                        enabled: !_isSubmitting,
                        obscureText: _obscurePassword,
                        validator: _validatePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Personal details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      controller: _nameController,
                      label: 'Name',
                      enabled: !_isSubmitting,
                      validator: (value) => Validators.required(
                        value,
                        message: 'Name is required',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      controller: _fatherNameController,
                      label: "Father's name",
                      enabled: !_isSubmitting,
                      validator: (value) => Validators.required(
                        value,
                        message: "Father's name is required",
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _dateOfBirth == null
                            ? 'Date of birth'
                            : 'Date of birth: ${_dateOfBirth!.toLocal()}'
                                  .split(' ')
                                  .first,
                      ),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: _isSubmitting ? null : _pickDateOfBirth,
                    ),
                    DropdownButtonFormField<Gender>(
                      initialValue: _gender,
                      decoration: const InputDecoration(labelText: 'Gender'),
                      items: Gender.values
                          .map(
                            (gender) => DropdownMenuItem(
                              value: gender,
                              child: Text(_genderLabel(gender)),
                            ),
                          )
                          .toList(),
                      onChanged: _isSubmitting
                          ? null
                          : (value) =>
                                setState(() => _gender = value ?? _gender),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      controller: _addressController,
                      label: 'Address',
                      enabled: !_isSubmitting,
                      validator: (value) => Validators.required(
                        value,
                        message: 'Address is required',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Academic details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      controller: _classController,
                      label: 'Class',
                      enabled: !_isSubmitting,
                      validator: (value) => Validators.required(
                        value,
                        message: 'Class is required',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      controller: _boardController,
                      label: 'Board',
                      enabled: !_isSubmitting,
                      validator: (value) => Validators.required(
                        value,
                        message: 'Board is required',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (widget.batches.isEmpty)
                      Text(
                        'No active batches yet. Create one under Batches first.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: _selectedBatchId,
                        decoration: const InputDecoration(labelText: 'Batch'),
                        items: widget.batches
                            .map(
                              (batch) => DropdownMenuItem(
                                value: batch.batchId,
                                child: Text(batch.name),
                              ),
                            )
                            .toList(),
                        onChanged: _isSubmitting ? null : _onBatchSelected,
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<PaymentPlan>(
                      initialValue: _paymentPlan,
                      decoration: const InputDecoration(
                        labelText: 'Payment plan',
                      ),
                      items: PaymentPlan.values
                          .map(
                            (plan) => DropdownMenuItem(
                              value: plan,
                              child: Text(plan.label),
                            ),
                          )
                          .toList(),
                      onChanged: _isSubmitting ? null : _onPaymentPlanSelected,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      controller: _sessionController,
                      label: 'Academic session',
                      hintText: 'e.g. 2026-27',
                      enabled: !_isSubmitting,
                      validator: (value) => Validators.required(
                        value,
                        message: 'Academic session is required',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Contact',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      controller: _primaryMobileController,
                      label: 'Primary mobile',
                      enabled: !_isSubmitting,
                      keyboardType: TextInputType.phone,
                      validator: (value) =>
                          Validators.phone(value, label: 'Primary mobile'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      controller: _secondaryMobileController,
                      label: 'Secondary mobile (optional)',
                      enabled: !_isSubmitting,
                      keyboardType: TextInputType.phone,
                      validator: (value) => Validators.phone(
                        value,
                        isRequired: false,
                        label: 'Secondary mobile',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Fee', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Standard fee (${_paymentPlan.label.toLowerCase()}, from batch): '
                      '₹${_standardFee.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      controller: _finalFeeController,
                      label: 'Final agreed fee',
                      enabled: !_isSubmitting,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: _validateAmount,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      discount == 0
                          ? 'No discount'
                          : 'Discount/adjustment: ₹${discount.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      controller: _feeReasonController,
                      label:
                          'Reason / remark (required if fee differs from standard)',
                      enabled: !_isSubmitting,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: _isEditing ? 'Save' : 'Admit student',
                      isLoading: _isSubmitting,
                      onPressed: widget.batches.isEmpty && !_isEditing
                          ? null
                          : _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _validateAccountId(String? value) {
    final requiredError = Validators.required(
      value,
      message: 'Account ID is required',
    );
    if (requiredError != null) return requiredError;
    if (!AppConstants.accountIdPattern.hasMatch(value!.trim().toLowerCase())) {
      return '3-24 characters: lowercase letters, numbers, . _ or -';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final requiredError = Validators.required(
      value,
      message: 'Password is required',
    );
    if (requiredError != null) return requiredError;
    if (value!.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  String? _validateAmount(String? value) {
    final requiredError = Validators.required(value, message: 'Required');
    if (requiredError != null) return requiredError;
    final parsed = double.tryParse(value!);
    if (parsed == null || parsed < 0) return 'Enter a valid amount';
    return null;
  }

  String _genderLabel(Gender gender) {
    switch (gender) {
      case Gender.male:
        return 'Male';
      case Gender.female:
        return 'Female';
      case Gender.other:
        return 'Other';
    }
  }
}
