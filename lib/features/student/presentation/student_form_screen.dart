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
import '../../academics/data/academics_repositories.dart';
import '../../academics/data/board.dart';
import '../../auth/application/auth_providers.dart';
import '../../batches/data/batch.dart';
import '../../batches/data/batch_repository.dart';
import '../../batches/data/installment_schedule_item.dart';
import '../application/student_form_controller.dart';
import '../data/student_profile.dart';
import '../data/student_repository.dart';
import 'installment_entry_dialog.dart';

/// Admit a new student, or edit an existing one's identity/contact
/// details. Pass [studentUid] to edit; omit it to admit a new student.
///
/// Academic session/class/batch and the fee agreement can only be SET
/// here at admission time - once a student is admitted, changing them
/// goes through the separate "Change batch" action (see
/// `ChangeBatchDialog`) instead of this form, so a historical fee
/// agreement is never silently overwritten (Set 11 spec).
class StudentFormScreen extends ConsumerWidget {
  const StudentFormScreen({super.key, this.studentUid});

  final String? studentUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (studentUid == null) {
      return const Scaffold(
        body: SafeArea(child: _StudentForm(existing: null)),
      );
    }

    final studentsAsync = ref.watch(allStudentsProvider);
    return Scaffold(
      body: SafeArea(
        child: studentsAsync.when(
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
            return _StudentForm(existing: existing);
          },
        ),
      ),
    );
  }
}

class _StudentForm extends ConsumerStatefulWidget {
  const _StudentForm({required this.existing});

  final StudentProfile? existing;

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
  late final _photoUrlController = TextEditingController(
    text: widget.existing?.photoUrl ?? '',
  );
  late final _fatherNameController = TextEditingController(
    text: widget.existing?.fatherName ?? '',
  );
  late final _addressController = TextEditingController(
    text: widget.existing?.address ?? '',
  );
  late final _boardCustomController = TextEditingController(
    text: widget.existing?.boardCustomText ?? '',
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
  String? _sessionId;
  String? _classId;
  String? _selectedBatchId;
  String? _boardId;
  double _standardFee = 0;
  PaymentPlan _paymentPlan = PaymentPlan.monthly;
  final List<InstallmentScheduleItem> _installments = [];

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
    _boardId = widget.existing?.boardId;
    _finalFeeController.addListener(_onFinalFeeChanged);
  }

  /// The standard fee depends on BOTH the selected batch and the chosen
  /// payment plan - a batch has separate monthly/installment fees (see
  /// [Batch]), so switching either one recomputes it.
  void _recomputeStandardFee(List<Batch> batches) {
    final batch = batches
        .where((b) => b.batchId == _selectedBatchId)
        .firstOrNull;
    if (batch == null) return;
    _standardFee = batch.standardFeeFor(
      isInstallment: _paymentPlan == PaymentPlan.installment,
    );
    // Auto-populate the final fee to match the standard fee - admin can
    // still adjust it below (that's the discount workflow).
    _finalFeeController.text = _standardFee.toStringAsFixed(0);
    if (batch.boardId != null) _boardId = batch.boardId;
  }

  void _onFinalFeeChanged() => setState(() {});

  @override
  void dispose() {
    _accountIdController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _photoUrlController.dispose();
    _fatherNameController.dispose();
    _addressController.dispose();
    _boardCustomController.dispose();
    _primaryMobileController.dispose();
    _secondaryMobileController.dispose();
    _finalFeeController.removeListener(_onFinalFeeChanged);
    _finalFeeController.dispose();
    _feeReasonController.dispose();
    super.dispose();
  }

  void _onSessionSelected(String? sessionId) {
    setState(() {
      _sessionId = sessionId;
      _selectedBatchId = null;
      _standardFee = 0;
    });
  }

  void _onClassSelected(String? classId) {
    setState(() {
      _classId = classId;
      _selectedBatchId = null;
      _standardFee = 0;
    });
  }

  void _onBatchSelected(String? batchId, List<Batch> matchingBatches) {
    if (batchId == null) return;
    setState(() {
      _selectedBatchId = batchId;
      _recomputeStandardFee(matchingBatches);
    });
  }

  void _onPaymentPlanSelected(PaymentPlan? plan, List<Batch> matchingBatches) {
    if (plan == null) return;
    setState(() {
      _paymentPlan = plan;
      _recomputeStandardFee(matchingBatches);
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

  Future<void> _addInstallment() async {
    final item = await showInstallmentEntryDialog(context);
    if (item != null) setState(() => _installments.add(item));
  }

  /// Merges the given master-data list with a currently selected id (even
  /// if that entry has since been deactivated), so editing an older
  /// record never silently drops its existing selection from a dropdown.
  List<T> _selectableOptions<T>(
    List<T> active,
    List<T> all,
    String Function(T) idOf,
    String? selectedId,
  ) {
    if (selectedId == null || active.any((item) => idOf(item) == selectedId)) {
      return active;
    }
    final existing = all.where((item) => idOf(item) == selectedId).firstOrNull;
    return existing == null ? active : [...active, existing];
  }

  String _resolveBoardDisplayName(Board? board, String customText) {
    if (board == null) return '';
    return board.name == 'Others' ? customText.trim() : board.name;
  }

  Future<void> _submit(List<Board> boards) async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    if (_dateOfBirth == null) {
      setState(() => _errorMessage = 'Date of birth is required.');
      return;
    }

    final selectedBoard = boards.where((b) => b.boardId == _boardId).firstOrNull;
    final boardDisplayName = _resolveBoardDisplayName(
      selectedBoard,
      _boardCustomController.text,
    );

    if (!_isEditing) {
      if (_sessionId == null || _classId == null || _selectedBatchId == null) {
        setState(
          () => _errorMessage = 'Select an academic session, class and batch.',
        );
        return;
      }
    }

    final finalFee = _isEditing
        ? widget.existing!.finalFee
        : double.parse(_finalFeeController.text);
    if (!_isEditing &&
        finalFee != _standardFee &&
        _feeReasonController.text.trim().isEmpty) {
      setState(
        () => _errorMessage =
            'A remark is required when the final fee differs from the standard fee.',
      );
      return;
    }
    if (!_isEditing &&
        _paymentPlan == PaymentPlan.installment &&
        _installments.isEmpty) {
      setState(
        () => _errorMessage = 'Add at least one installment.',
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

      if (_isEditing) {
        await controller.updateStudent(
          existing: widget.existing!,
          name: _nameController.text,
          fatherName: _fatherNameController.text,
          dateOfBirth: _dateOfBirth!,
          gender: _gender,
          photoUrl: _photoUrlController.text,
          address: _addressController.text,
          primaryMobile: _primaryMobileController.text,
          secondaryMobile: secondaryMobile,
          boardId: _boardId,
          boardCustomText: _boardCustomController.text,
          boardDisplayName: boardDisplayName,
        );
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }

      final sessions = ref.read(allAcademicSessionsProvider).valueOrNull ?? [];
      final classes = ref.read(activeSchoolClassesProvider).valueOrNull ?? [];
      final sessionName =
          sessions.where((s) => s.sessionId == _sessionId).firstOrNull?.name ??
          '';
      final className =
          classes.where((c) => c.classId == _classId).firstOrNull?.name ?? '';
      final adminUid = ref.read(currentUserAccountProvider).valueOrNull?.uid;

      final feeReason = _feeReasonController.text.trim().isEmpty
          ? null
          : _feeReasonController.text;

      final result = await controller.admitStudent(
        accountId: _accountIdController.text,
        password: _passwordController.text,
        name: _nameController.text,
        fatherName: _fatherNameController.text,
        dateOfBirth: _dateOfBirth!,
        gender: _gender,
        photoUrl: _photoUrlController.text,
        address: _addressController.text,
        academicSessionId: _sessionId!,
        academicSessionName: sessionName,
        classId: _classId!,
        className: className,
        batchId: _selectedBatchId!,
        boardId: _boardId,
        boardCustomText: _boardCustomController.text,
        boardDisplayName: boardDisplayName,
        primaryMobile: _primaryMobileController.text,
        secondaryMobile: secondaryMobile,
        standardFee: _standardFee,
        finalFee: finalFee,
        feeReason: feeReason,
        paymentPlan: _paymentPlan,
        installments: _installments,
        configuredByUid: adminUid ?? '',
      );

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Student admitted'),
          content: Text(
            'Admission number: ${result.admissionNumber}\n'
            'Account ID: ${result.accountId}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
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
    final activeBoardsAsync = ref.watch(activeBoardsProvider);
    final allBoardsAsync = ref.watch(allBoardsProvider);
    final boards = allBoardsAsync.valueOrNull ?? const <Board>[];
    final activeBoards = activeBoardsAsync.valueOrNull ?? const <Board>[];
    final selectedBoard = boards.where((b) => b.boardId == _boardId).firstOrNull;
    final isOthersBoard = selectedBoard?.name == 'Others';

    final discount =
        _standardFee -
        (double.tryParse(_finalFeeController.text) ?? _standardFee);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit student' : 'New admission'),
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
                      'Student information',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      controller: _nameController,
                      label: 'Student name *',
                      enabled: !_isSubmitting,
                      validator: (value) => Validators.required(
                        value,
                        message: 'Student name is required',
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
                      decoration: const InputDecoration(
                        labelText: 'Gender *',
                      ),
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
                      controller: _photoUrlController,
                      label: 'Photo URL (optional - paste an image link)',
                      enabled: !_isSubmitting,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Parent & contact',
                      style: Theme.of(context).textTheme.titleLarge,
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
                    AppTextField(
                      controller: _primaryMobileController,
                      label: 'Primary mobile *',
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
                      'Academic information',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (_isEditing)
                      _ReadOnlyAcademicSummary(existing: widget.existing!)
                    else
                      _AcademicPickers(
                        sessionId: _sessionId,
                        classId: _classId,
                        selectedBatchId: _selectedBatchId,
                        isSubmitting: _isSubmitting,
                        onSessionChanged: _onSessionSelected,
                        onClassChanged: _onClassSelected,
                        onBatchChanged: _onBatchSelected,
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    activeBoardsAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (error, stackTrace) => const SizedBox.shrink(),
                      data: (_) => DropdownButtonFormField<String?>(
                        key: ValueKey('board-$_boardId'),
                        initialValue: _boardId,
                        decoration: const InputDecoration(
                          labelText: 'Board (optional)',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Not specified'),
                          ),
                          for (final board in _selectableOptions(
                            activeBoards,
                            boards,
                            (b) => b.boardId,
                            _boardId,
                          ))
                            DropdownMenuItem<String?>(
                              value: board.boardId,
                              child: Text(board.name),
                            ),
                        ],
                        onChanged: _isSubmitting
                            ? null
                            : (value) => setState(() => _boardId = value),
                      ),
                    ),
                    if (isOthersBoard) ...[
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        controller: _boardCustomController,
                        label: 'Board name (since "Others" was selected)',
                        enabled: !_isSubmitting,
                        validator: (value) => Validators.required(
                          value,
                          message: 'Enter the board name',
                        ),
                      ),
                    ],
                    if (!_isEditing) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Fee & payment information',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Builder(
                        builder: (context) {
                          final batches =
                              ref.watch(activeBatchesProvider).valueOrNull ??
                              const <Batch>[];
                          final matching = batchesForSessionAndClass(
                            batches,
                            academicSessionId: _sessionId,
                            classId: _classId,
                          );
                          return DropdownButtonFormField<PaymentPlan>(
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
                            onChanged: _isSubmitting
                                ? null
                                : (value) =>
                                      _onPaymentPlanSelected(value, matching),
                          );
                        },
                      ),
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
                        validator: (value) =>
                            Validators.amount(value, label: 'Final agreed fee'),
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
                            'Remark (required if fee differs from standard)',
                        enabled: !_isSubmitting,
                      ),
                      if (_paymentPlan == PaymentPlan.installment) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Installment schedule',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        for (final item in _installments)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${item.label} - ₹${item.amount.toStringAsFixed(0)}',
                            ),
                            subtitle: Text(
                              'Due ${item.dueDate.toLocal()}'.split(' ').first,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: _isSubmitting
                                  ? null
                                  : () => setState(
                                      () => _installments.remove(item),
                                    ),
                            ),
                          ),
                        TextButton.icon(
                          onPressed: _isSubmitting ? null : _addInstallment,
                          icon: const Icon(Icons.add),
                          label: const Text('Add installment'),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Account information',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    if (_isEditing) const SizedBox(height: AppSpacing.lg),
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
                    AppButton(
                      label: _isEditing ? 'Save' : 'Admit student',
                      isLoading: _isSubmitting,
                      onPressed: () => _submit(boards),
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

/// Session -> class -> (only matching batches) cascading pickers for a
/// new admission (Set 11 spec section 8) - inactive batches are never
/// offered, since [activeBatchesProvider] already excludes them.
class _AcademicPickers extends ConsumerWidget {
  const _AcademicPickers({
    required this.sessionId,
    required this.classId,
    required this.selectedBatchId,
    required this.isSubmitting,
    required this.onSessionChanged,
    required this.onClassChanged,
    required this.onBatchChanged,
  });

  final String? sessionId;
  final String? classId;
  final String? selectedBatchId;
  final bool isSubmitting;
  final ValueChanged<String?> onSessionChanged;
  final ValueChanged<String?> onClassChanged;
  final void Function(String?, List<Batch>) onBatchChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(allAcademicSessionsProvider);
    final classesAsync = ref.watch(activeSchoolClassesProvider);
    final batchesAsync = ref.watch(activeBatchesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sessionsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (error, stackTrace) => const SizedBox.shrink(),
          data: (sessions) => DropdownButtonFormField<String>(
            initialValue: sessionId,
            decoration: const InputDecoration(
              labelText: 'Academic session *',
            ),
            items: [
              for (final session in sessions)
                DropdownMenuItem(
                  value: session.sessionId,
                  child: Text(session.name),
                ),
            ],
            onChanged: isSubmitting ? null : onSessionChanged,
            validator: (value) =>
                value == null ? 'Select an academic session' : null,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        classesAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (error, stackTrace) => const SizedBox.shrink(),
          data: (classes) => DropdownButtonFormField<String>(
            initialValue: classId,
            decoration: const InputDecoration(labelText: 'Class *'),
            items: [
              for (final schoolClass in classes)
                DropdownMenuItem(
                  value: schoolClass.classId,
                  child: Text(schoolClass.name),
                ),
            ],
            onChanged: isSubmitting ? null : onClassChanged,
            validator: (value) => value == null ? 'Select a class' : null,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        batchesAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (error, stackTrace) => const SizedBox.shrink(),
          data: (batches) {
            final matching = batchesForSessionAndClass(
              batches,
              academicSessionId: sessionId,
              classId: classId,
            );
            if (sessionId == null || classId == null) {
              return const Text(
                'Select a session and class to see matching batches.',
              );
            }
            if (matching.isEmpty) {
              return Text(
                'No active batches for this session/class yet.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              );
            }
            return DropdownButtonFormField<String>(
              key: ValueKey('batch-$sessionId-$classId'),
              initialValue: matching.any((b) => b.batchId == selectedBatchId)
                  ? selectedBatchId
                  : null,
              decoration: const InputDecoration(labelText: 'Batch *'),
              items: [
                for (final batch in matching)
                  DropdownMenuItem(value: batch.batchId, child: Text(batch.name)),
              ],
              onChanged: isSubmitting
                  ? null
                  : (value) => onBatchChanged(value, matching),
              validator: (value) => value == null ? 'Select a batch' : null,
            );
          },
        ),
      ],
    );
  }
}

/// Read-only academic summary shown while editing a student - session/
/// class/batch/fee only ever change via "Change batch" on the profile
/// screen, never through this form.
class _ReadOnlyAcademicSummary extends ConsumerWidget {
  const _ReadOnlyAcademicSummary({required this.existing});

  final StudentProfile existing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batches = ref.watch(allBatchesProvider).valueOrNull ?? const [];
    final batchName = batches
        .where((b) => b.batchId == existing.batchId)
        .firstOrNull
        ?.name;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Session: ${existing.academicSession}'),
          Text('Class: ${existing.className}'),
          Text('Batch: ${batchName ?? existing.batchId}'),
          const SizedBox(height: 4),
          Text(
            'To change the batch, class, session or fee agreement, use '
            '"Change batch" from the student\'s profile.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
