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
import '../data/subject.dart';

/// Admin's subject master - which classes a subject applies to is
/// configured from the Classes screen (a class picks its own subjects),
/// not here; see [SchoolClass]'s doc comment for why.
class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(allSubjectsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Subjects')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSubjectForm(context),
        icon: const Icon(Icons.add),
        label: const Text('New subject'),
      ),
      body: SafeArea(
        child: subjectsAsync.when(
          loading: () => const LoadingView(message: 'Loading subjects...'),
          error: (error, stackTrace) =>
              ErrorView(message: 'Could not load subjects.\n$error'),
          data: (subjects) {
            if (subjects.isEmpty) {
              return const EmptyView(
                message: 'No subjects yet. Create one to get started.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: subjects.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) =>
                  _SubjectTile(subject: subjects[index]),
            );
          },
        ),
      ),
    );
  }
}

class _SubjectTile extends ConsumerWidget {
  const _SubjectTile({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        title: Text(subject.name),
        subtitle: subject.active ? null : const Text('Inactive'),
        onTap: () => _showSubjectForm(context, existing: subject),
        trailing: PopupMenuButton<bool>(
          onSelected: (active) async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              await ref
                  .read(academicConfigControllerProvider)
                  .setSubjectActive(subject, active);
            } on AcademicConfigFailure catch (failure) {
              messenger.showSnackBar(SnackBar(content: Text(failure.message)));
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: !subject.active,
              child: Text(subject.active ? 'Deactivate' : 'Activate'),
            ),
          ],
        ),
      ),
    );
  }
}

void _showSubjectForm(BuildContext context, {Subject? existing}) {
  showDialog<void>(
    context: context,
    builder: (context) => _SubjectFormDialog(existing: existing),
  );
}

class _SubjectFormDialog extends ConsumerStatefulWidget {
  const _SubjectFormDialog({this.existing});

  final Subject? existing;

  @override
  ConsumerState<_SubjectFormDialog> createState() => _SubjectFormDialogState();
}

class _SubjectFormDialogState extends ConsumerState<_SubjectFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
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
          .saveSubject(existing: widget.existing, name: _nameController.text);
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
      title: Text(widget.existing == null ? 'New subject' : 'Edit subject'),
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
              label: 'Subject name',
              enabled: !_isSubmitting,
              validator: (value) => Validators.required(
                value,
                message: 'Subject name is required',
              ),
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
