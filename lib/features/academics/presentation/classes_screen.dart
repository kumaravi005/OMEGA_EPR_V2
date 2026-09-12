import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../application/academic_config_controller.dart';
import '../data/academics_repositories.dart';
import '../data/school_class.dart';
import '../data/subject.dart';

/// Admin's class master (Class 5-12 initially) - each class also owns
/// which subjects apply to it (tap "Subjects" on a class to configure),
/// so a future homework/test/attendance screen can query "what subjects
/// does this class offer" from one place instead of a hard-coded list.
class ClassesScreen extends ConsumerWidget {
  const ClassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(allSchoolClassesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Classes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            _showClassForm(context, classesAsync.valueOrNull ?? const []),
        icon: const Icon(Icons.add),
        label: const Text('New class'),
      ),
      body: SafeArea(
        child: classesAsync.when(
          loading: () => const LoadingView(message: 'Loading classes...'),
          error: (error, stackTrace) =>
              ErrorView(message: 'Could not load classes.\n$error'),
          data: (classes) {
            if (classes.isEmpty) {
              return const EmptyView(
                message: 'No classes yet. Create one to get started.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: classes.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) =>
                  _ClassTile(schoolClass: classes[index], allClasses: classes),
            );
          },
        ),
      ),
    );
  }
}

class _ClassTile extends ConsumerWidget {
  const _ClassTile({required this.schoolClass, required this.allClasses});

  final SchoolClass schoolClass;
  final List<SchoolClass> allClasses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(allSubjectsProvider);
    final subjectNames = subjectsAsync.valueOrNull == null
        ? ''
        : schoolClass.subjectIds
              .map(
                (id) =>
                    subjectsAsync.valueOrNull!
                        .where((s) => s.subjectId == id)
                        .firstOrNull
                        ?.name ??
                    id,
              )
              .join(', ');

    return Card(
      child: ListTile(
        title: Text(schoolClass.name),
        subtitle: Text(
          [
            if (subjectNames.isNotEmpty)
              subjectNames
            else
              'No subjects configured',
            if (!schoolClass.active) 'Inactive',
          ].join(' - '),
        ),
        onTap: () => _showClassForm(context, allClasses, existing: schoolClass),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.menu_book_outlined),
              tooltip: 'Subjects',
              onPressed: () => _showSubjectPicker(context, ref),
            ),
            PopupMenuButton<bool>(
              onSelected: (active) async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await ref
                      .read(academicConfigControllerProvider)
                      .setClassActive(schoolClass, active);
                } on AcademicConfigFailure catch (failure) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(failure.message)),
                  );
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: !schoolClass.active,
                  child: Text(schoolClass.active ? 'Deactivate' : 'Activate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSubjectPicker(BuildContext context, WidgetRef ref) async {
    final subjects =
        ref.read(allSubjectsProvider).valueOrNull ?? const <Subject>[];
    if (subjects.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Add a subject first.')));
      return;
    }

    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (context) => _SubjectPickerDialog(
        subjects: subjects,
        initiallySelected: schoolClass.subjectIds.toSet(),
      ),
    );
    if (selected == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(academicConfigControllerProvider)
          .setClassSubjects(schoolClass, selected.toList());
    } on AcademicConfigFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}

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
      title: const Text('Subjects for this class'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
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

void _showClassForm(
  BuildContext context,
  List<SchoolClass> allClasses, {
  SchoolClass? existing,
}) {
  showDialog<void>(
    context: context,
    builder: (context) =>
        _ClassFormDialog(existing: existing, allClasses: allClasses),
  );
}

class _ClassFormDialog extends ConsumerStatefulWidget {
  const _ClassFormDialog({this.existing, required this.allClasses});

  final SchoolClass? existing;
  final List<SchoolClass> allClasses;

  @override
  ConsumerState<_ClassFormDialog> createState() => _ClassFormDialogState();
}

class _ClassFormDialogState extends ConsumerState<_ClassFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final _sortOrderController = TextEditingController(
    text: (widget.existing?.sortOrder ?? (widget.allClasses.length + 1))
        .toString(),
  );

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _sortOrderController.dispose();
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
          .read(academicConfigControllerProvider)
          .saveClass(
            existing: widget.existing,
            name: _nameController.text,
            sortOrder: int.parse(_sortOrderController.text),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on AcademicConfigFailure catch (failure) {
      setState(() => _errorMessage = failure.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New class' : 'Edit class'),
      content: Form(
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
              label: 'Class name',
              hintText: 'e.g. Class 9',
              enabled: !_isSubmitting,
              validator: (value) =>
                  Validators.required(value, message: 'Class name is required'),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _sortOrderController,
              label: 'Display order',
              enabled: !_isSubmitting,
              keyboardType: TextInputType.number,
              validator: (value) {
                final requiredError = Validators.required(
                  value,
                  message: 'Required',
                );
                if (requiredError != null) return requiredError;
                return int.tryParse(value!) == null
                    ? 'Enter a whole number'
                    : null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        AppButton(label: 'Save', isLoading: _isSubmitting, onPressed: _submit),
      ],
    );
  }
}
