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
import '../application/teacher_form_controller.dart';
import '../data/teacher_profile.dart';
import '../data/teacher_repository.dart';

/// Create or edit a teacher. Pass [teacherUid] to edit an existing
/// teacher; omit it to create a new one.
class TeacherFormScreen extends ConsumerWidget {
  const TeacherFormScreen({super.key, this.teacherUid});

  final String? teacherUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (teacherUid == null) {
      return const Scaffold(
        body: SafeArea(child: _TeacherForm(existing: null)),
      );
    }

    final teachersAsync = ref.watch(allTeachersProvider);
    return Scaffold(
      body: SafeArea(
        child: teachersAsync.when(
          loading: () => const LoadingView(),
          error: (error, stackTrace) =>
              ErrorView(message: 'Could not load teacher.\n$error'),
          data: (teachers) {
            final existing = teachers
                .where((t) => t.uid == teacherUid)
                .firstOrNull;
            if (existing == null) {
              return const ErrorView(message: 'Teacher not found.');
            }
            return _TeacherForm(existing: existing);
          },
        ),
      ),
    );
  }
}

class _AssignmentRowControllers {
  _AssignmentRowControllers({String className = '', String subject = ''})
    : classNameController = TextEditingController(text: className),
      subjectController = TextEditingController(text: subject);

  final TextEditingController classNameController;
  final TextEditingController subjectController;

  void dispose() {
    classNameController.dispose();
    subjectController.dispose();
  }
}

class _TeacherForm extends ConsumerStatefulWidget {
  const _TeacherForm({required this.existing});

  final TeacherProfile? existing;

  @override
  ConsumerState<_TeacherForm> createState() => _TeacherFormState();
}

class _TeacherFormState extends ConsumerState<_TeacherForm> {
  final _formKey = GlobalKey<FormState>();
  late final _accountIdController = TextEditingController(
    text: widget.existing?.accountId ?? '',
  );
  final _passwordController = TextEditingController();
  late final _nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final _qualificationController = TextEditingController(
    text: widget.existing?.qualification ?? '',
  );
  late final _addressController = TextEditingController(
    text: widget.existing?.address ?? '',
  );
  late final _primaryMobileController = TextEditingController(
    text: widget.existing?.primaryMobile ?? '',
  );
  late final _secondaryMobileController = TextEditingController(
    text: widget.existing?.secondaryMobile ?? '',
  );

  DateTime? _dateOfBirth;
  Gender _gender = Gender.male;
  final List<_AssignmentRowControllers> _assignmentRows = [];

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _dateOfBirth = widget.existing?.dateOfBirth;
    _gender = widget.existing?.gender ?? Gender.male;
    for (final assignment
        in widget.existing?.assignments ?? const <ClassSubjectAssignment>[]) {
      _assignmentRows.add(
        _AssignmentRowControllers(
          className: assignment.className,
          subject: assignment.subject,
        ),
      );
    }
  }

  @override
  void dispose() {
    _accountIdController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _qualificationController.dispose();
    _addressController.dispose();
    _primaryMobileController.dispose();
    _secondaryMobileController.dispose();
    for (final row in _assignmentRows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 90),
      lastDate: now,
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  void _addAssignmentRow() {
    setState(() => _assignmentRows.add(_AssignmentRowControllers()));
  }

  void _removeAssignmentRow(int index) {
    setState(() => _assignmentRows.removeAt(index).dispose());
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    if (_dateOfBirth == null) {
      setState(() => _errorMessage = 'Date of birth is required.');
      return;
    }

    final assignments = _assignmentRows
        .map(
          (row) => ClassSubjectAssignment(
            className: row.classNameController.text.trim(),
            subject: row.subjectController.text.trim(),
          ),
        )
        .where((a) => a.className.isNotEmpty && a.subject.isNotEmpty)
        .toList();

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final controller = ref.read(teacherFormControllerProvider);
      final secondaryMobile = _secondaryMobileController.text.trim().isEmpty
          ? null
          : _secondaryMobileController.text;
      if (_isEditing) {
        await controller.updateTeacher(
          existing: widget.existing!,
          name: _nameController.text,
          dateOfBirth: _dateOfBirth!,
          gender: _gender,
          qualification: _qualificationController.text,
          address: _addressController.text,
          primaryMobile: _primaryMobileController.text,
          secondaryMobile: secondaryMobile,
          assignments: assignments,
        );
      } else {
        await controller.createTeacher(
          accountId: _accountIdController.text,
          password: _passwordController.text,
          name: _nameController.text,
          dateOfBirth: _dateOfBirth!,
          gender: _gender,
          qualification: _qualificationController.text,
          address: _addressController.text,
          primaryMobile: _primaryMobileController.text,
          secondaryMobile: secondaryMobile,
          assignments: assignments,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on TeacherFormFailure catch (failure) {
      setState(() => _errorMessage = failure.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit teacher' : 'New teacher')),
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
                      controller: _qualificationController,
                      label: 'Qualification',
                      enabled: !_isSubmitting,
                      validator: (value) => Validators.required(
                        value,
                        message: 'Qualification is required',
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Class / subject assignments',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: _isSubmitting ? null : _addAssignmentRow,
                        ),
                      ],
                    ),
                    for (var i = 0; i < _assignmentRows.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller:
                                    _assignmentRows[i].classNameController,
                                label: 'Class',
                                enabled: !_isSubmitting,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: AppTextField(
                                controller:
                                    _assignmentRows[i].subjectController,
                                label: 'Subject',
                                enabled: !_isSubmitting,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: _isSubmitting
                                  ? null
                                  : () => _removeAssignmentRow(i),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: 'Save',
                      isLoading: _isSubmitting,
                      onPressed: _submit,
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
