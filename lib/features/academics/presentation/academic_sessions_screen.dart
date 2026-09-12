import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../application/academic_config_controller.dart';
import '../data/academic_session.dart';
import '../data/academics_repositories.dart';

/// Admin's list of academic sessions - create, edit, and switch which
/// one is active. Sessions are never deleted (only the "active" flag
/// moves, and firestore.rules denies delete on this collection
/// entirely) - "Do not delete historical session data accidentally".
class AcademicSessionsScreen extends ConsumerWidget {
  const AcademicSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(allAcademicSessionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Academic sessions')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSessionForm(context),
        icon: const Icon(Icons.add),
        label: const Text('New session'),
      ),
      body: SafeArea(
        child: sessionsAsync.when(
          loading: () => const LoadingView(message: 'Loading sessions...'),
          error: (error, stackTrace) =>
              ErrorView(message: 'Could not load sessions.\n$error'),
          data: (sessions) {
            if (sessions.isEmpty) {
              return const EmptyView(
                message: 'No academic sessions yet. Create one to get started.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: sessions.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) =>
                  _SessionTile(session: sessions[index]),
            );
          },
        ),
      ),
    );
  }
}

class _SessionTile extends ConsumerWidget {
  const _SessionTile({required this.session});

  final AcademicSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: session.isActive
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      child: ListTile(
        title: Text(session.name),
        subtitle: Text(
          '${dateKey(session.startDate)} - ${dateKey(session.endDate)}',
        ),
        onTap: () => _showSessionForm(context, existing: session),
        trailing: session.isActive
            ? const Chip(label: Text('Active'))
            : TextButton(
                onPressed: () => _confirmSetActive(context, ref),
                child: const Text('Set active'),
              ),
      ),
    );
  }

  Future<void> _confirmSetActive(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change active session?'),
        content: Text(
          'Make "${session.name}" the active academic session? The '
          'previously active session (if any) will no longer be active - '
          'its data is not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Set active'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(academicConfigControllerProvider)
          .setActiveSession(session);
    } on AcademicConfigFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}

void _showSessionForm(BuildContext context, {AcademicSession? existing}) {
  showDialog<void>(
    context: context,
    builder: (context) => _SessionFormDialog(existing: existing),
  );
}

class _SessionFormDialog extends ConsumerStatefulWidget {
  const _SessionFormDialog({this.existing});

  final AcademicSession? existing;

  @override
  ConsumerState<_SessionFormDialog> createState() => _SessionFormDialogState();
}

class _SessionFormDialogState extends ConsumerState<_SessionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late DateTime _startDate = widget.existing?.startDate ?? DateTime.now();
  late DateTime _endDate =
      widget.existing?.endDate ?? DateTime.now().add(const Duration(days: 365));

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(_startDate.year - 5),
      lastDate: DateTime(_startDate.year + 5),
    );
    if (picked == null) return;
    setState(() => isStart ? _startDate = picked : _endDate = picked);
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    if (!_endDate.isAfter(_startDate)) {
      setState(() => _errorMessage = 'End date must be after the start date.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(academicConfigControllerProvider)
          .saveSession(
            existing: widget.existing,
            name: _nameController.text,
            startDate: _startDate,
            endDate: _endDate,
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
      title: Text(
        widget.existing == null
            ? 'New academic session'
            : 'Edit academic session',
      ),
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
              label: 'Session name',
              hintText: 'e.g. 2026-27',
              enabled: !_isSubmitting,
              validator: (value) => Validators.required(
                value,
                message: 'Session name is required',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Start date: ${dateKey(_startDate)}'),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _isSubmitting ? null : () => _pickDate(isStart: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('End date: ${dateKey(_endDate)}'),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _isSubmitting ? null : () => _pickDate(isStart: false),
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
