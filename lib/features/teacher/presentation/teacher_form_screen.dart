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
import '../../academics/data/subject.dart';
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
  late final _photoUrlController = TextEditingController(
    text: widget.existing?.photoUrl ?? '',
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
  late final Set<String> _subjectIds = {...?widget.existing?.subjectIds};

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _dateOfBirth = widget.existing?.dateOfBirth;
    _gender = widget.existing?.gender ?? Gender.male;
  }

  @override
  void dispose() {
    _accountIdController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _photoUrlController.dispose();
    _qualificationController.dispose();
    _addressController.dispose();
    _primaryMobileController.dispose();
    _secondaryMobileController.dispose();
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

  Future<void> _editSubjects(List<Subject> selectableSubjects) async {
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (context) => _SubjectPickerDialog(
        subjects: selectableSubjects,
        initiallySelected: _subjectIds,
      ),
    );
    if (selected != null) {
      setState(
        () => _subjectIds
          ..clear()
          ..addAll(selected),
      );
    }
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    if (_dateOfBirth == null) {
      setState(() => _errorMessage = 'Date of birth is required.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final controller = ref.read(teacherFormControllerProvider);
      final secondaryMobile = _secondaryMobileController.text.trim().isEmpty
          ? null
          : _secondaryMobileController.text;
      final subjectIds = _subjectIds.toList();

      if (_isEditing) {
        await controller.updateTeacher(
          existing: widget.existing!,
          name: _nameController.text,
          dateOfBirth: _dateOfBirth!,
          gender: _gender,
          photoUrl: _photoUrlController.text,
          qualification: _qualificationController.text,
          address: _addressController.text,
          primaryMobile: _primaryMobileController.text,
          secondaryMobile: secondaryMobile,
          subjectIds: subjectIds,
        );
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }

      final result = await controller.createTeacher(
        accountId: _accountIdController.text,
        password: _passwordController.text,
        name: _nameController.text,
        dateOfBirth: _dateOfBirth!,
        gender: _gender,
        photoUrl: _photoUrlController.text,
        qualification: _qualificationController.text,
        address: _addressController.text,
        primaryMobile: _primaryMobileController.text,
        secondaryMobile: secondaryMobile,
        subjectIds: subjectIds,
      );

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Teacher added'),
          content: Text(
            'Teacher name: ${result.teacherName}\n'
            'Teacher ID: ${result.teacherId}\n'
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
    } on TeacherFormFailure catch (failure) {
      setState(() => _errorMessage = failure.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeSubjectsAsync = ref.watch(activeSubjectsProvider);
    final allSubjectsAsync = ref.watch(allSubjectsProvider);
    final allSubjects = allSubjectsAsync.valueOrNull ?? const <Subject>[];
    final activeSubjects = activeSubjectsAsync.valueOrNull ?? const <Subject>[];
    // Merge in any already-selected subject that has since been
    // deactivated, so editing a teacher never silently drops it from
    // both the display and the picker (same pattern as batch/session
    // pickers elsewhere in the app).
    final selectableSubjects = [
      ...activeSubjects,
      for (final subject in allSubjects)
        if (_subjectIds.contains(subject.subjectId) &&
            !activeSubjects.any((s) => s.subjectId == subject.subjectId))
          subject,
    ];
    final selectedSubjectNames = allSubjects
        .where((s) => _subjectIds.contains(s.subjectId))
        .map((s) => s.name)
        .toList();

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
                      'Personal information',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      controller: _nameController,
                      label: 'Teacher name *',
                      enabled: !_isSubmitting,
                      validator: (value) => Validators.required(
                        value,
                        message: 'Teacher name is required',
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
                      decoration: const InputDecoration(labelText: 'Gender *'),
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
                      'Professional information',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      controller: _qualificationController,
                      label: 'Qualification',
                      enabled: !_isSubmitting,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Contact information',
                      style: Theme.of(context).textTheme.titleLarge,
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Subjects taught',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _isSubmitting
                              ? null
                              : () => _editSubjects(selectableSubjects),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit'),
                        ),
                      ],
                    ),
                    if (selectedSubjectNames.isEmpty)
                      Text(
                        'No subjects selected yet.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    else
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final name in selectedSubjectNames)
                            Chip(label: Text(name)),
                        ],
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      _isEditing ? 'Account information' : 'Account creation',
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
                    AppButton(
                      label: _isEditing ? 'Save' : 'Add teacher',
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

/// Multi-select checkbox dialog over the subject master - mirrors
/// `_SubjectPickerDialog` in `academics/presentation/classes_screen.dart`
/// (same visual treatment: `CheckboxListTile` list, Cancel/Save actions,
/// returning the chosen set of `Subject.subjectId`s) so a teacher's
/// "subjects taught" picker looks and behaves identically to a class's
/// subject picker.
class _SubjectPickerDialog extends StatefulWidget {
  const _SubjectPickerDialog({
    required this.subjects,
    required this.initiallySelected,
  });

  final List<Subject> subjects;
  final Set<String> initiallySelected;

  @override
  State<_SubjectPickerDialog> createState() => _SubjectPickerDialogState();
}

class _SubjectPickerDialogState extends State<_SubjectPickerDialog> {
  late final Set<String> _selected = {...widget.initiallySelected};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Subjects taught'),
      content: SizedBox(
        width: 360,
        child: widget.subjects.isEmpty
            ? const Text('No subjects configured yet.')
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final subject in widget.subjects)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(subject.name),
                        value: _selected.contains(subject.subjectId),
                        onChanged: (checked) => setState(() {
                          if (checked ?? false) {
                            _selected.add(subject.subjectId);
                          } else {
                            _selected.remove(subject.subjectId);
                          }
                        }),
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
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
