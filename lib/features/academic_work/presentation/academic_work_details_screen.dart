import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../academics/data/academics_repositories.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/data/user_account.dart';
import '../../batches/data/batch_repository.dart';
import '../../teacher_assignments/data/teacher_assignment_repository.dart';
import '../application/academic_work_controller.dart';
import '../data/academic_work.dart';
import '../data/academic_work_repository.dart';

/// Academic Information / Homework Information / Record Information,
/// plus edit/publish/close controls for admin, or a teacher whose own
/// active `TeacherAssignment` matches this item's session/class/batch/
/// subject (Set 22/23 - previously admin-only) - everyone else (a
/// teacher without a matching assignment, student/parent) gets the same
/// layout read-only, which is exactly the "opening an item should show
/// full instructions" view the Set 16 spec asks for on the student side
/// too, so this one screen serves every role reachable from `basePath`
/// (mirrors `TestDetailsScreen`'s admin/teacher reuse from Set 14/15).
class AcademicWorkDetailsScreen extends ConsumerWidget {
  const AcademicWorkDetailsScreen({super.key, required this.workId});

  final String workId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workAsync = ref.watch(academicWorkByIdProvider(workId));

    return Scaffold(
      appBar: AppBar(title: const Text('Details')),
      body: SafeArea(
        child: workAsync.when(
          loading: () => const LoadingView(),
          error: (error, stackTrace) =>
              ErrorView(message: 'Unable to load this item. Please try again.\n$error'),
          data: (work) {
            if (work == null) {
              return const ErrorView(message: 'Not found.');
            }
            return _DetailsBody(work: work);
          },
        ),
      ),
    );
  }
}

class _DetailsBody extends ConsumerWidget {
  const _DetailsBody({required this.work});

  final AcademicWork work;

  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    AcademicWorkStatus status,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(academicWorkControllerProvider).setStatus(work, status);
    } on AcademicWorkFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _EditAcademicWorkDialog(work: work),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(currentUserAccountProvider).valueOrNull;
    final isAdmin = account?.role == UserRole.admin;
    final isTeacher = account?.role == UserRole.teacher;
    final teacherCanManage = isTeacher && account != null
        ? teacherCanOperateOn(
            ref.watch(ownTeacherAssignmentsProvider(account.uid)).valueOrNull ??
                const [],
            academicSessionId: work.academicSessionId,
            batchId: work.batchId,
            subjectId: work.subjectId,
          )
        : false;
    final canManage = isAdmin || teacherCanManage;
    final sessions = ref.watch(allAcademicSessionsProvider).valueOrNull ?? [];
    final classes = ref.watch(allSchoolClassesProvider).valueOrNull ?? [];
    final batches = ref.watch(allBatchesProvider).valueOrNull ?? [];

    final sessionName = sessions
        .where((s) => s.sessionId == work.academicSessionId)
        .firstOrNull
        ?.name;
    final className = classes
        .where((c) => c.classId == work.classId)
        .firstOrNull
        ?.name;
    final batchName = batches
        .where((b) => b.batchId == work.batchId)
        .firstOrNull
        ?.name;
    final overdue = work.isOverdue(DateTime.now());

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    work.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                Chip(label: Text(work.status.label)),
              ],
            ),
            if (overdue)
              Text(
                'Overdue',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Academic information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(label: 'Session', value: sessionName ?? '-'),
                  _InfoRow(label: 'Class', value: className ?? '-'),
                  _InfoRow(label: 'Batch', value: batchName ?? '-'),
                  _InfoRow(label: 'Subject', value: work.subject),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${work.type.label} information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(label: 'Type', value: work.type.label),
                  _InfoRow(
                    label: 'Assigned date',
                    value: dateKey(work.assignedDate),
                  ),
                  _InfoRow(label: 'Due date', value: dateKey(work.dueDate)),
                  if (work.description != null && work.description!.isNotEmpty)
                    _InfoRow(label: 'Description', value: work.description!),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Record information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(label: 'Created', value: dateKey(work.createdAt)),
                  _InfoRow(label: 'Updated', value: dateKey(work.updatedAt)),
                ],
              ),
            ),
            if (canManage) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Edit',
                onPressed: () => _edit(context, ref),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  if (work.status != AcademicWorkStatus.draft)
                    Expanded(
                      child: AppButton(
                        label: 'Mark draft',
                        variant: AppButtonVariant.secondary,
                        onPressed: () =>
                            _setStatus(context, ref, AcademicWorkStatus.draft),
                      ),
                    ),
                  if (work.status != AcademicWorkStatus.published) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppButton(
                        label: 'Publish',
                        onPressed: () => _setStatus(
                          context,
                          ref,
                          AcademicWorkStatus.published,
                        ),
                      ),
                    ),
                  ],
                  if (work.status != AcademicWorkStatus.closed) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppButton(
                        label: 'Close',
                        variant: AppButtonVariant.secondary,
                        onPressed: () => _setStatus(
                          context,
                          ref,
                          AcademicWorkStatus.closed,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EditAcademicWorkDialog extends ConsumerStatefulWidget {
  const _EditAcademicWorkDialog({required this.work});

  final AcademicWork work;

  @override
  ConsumerState<_EditAcademicWorkDialog> createState() =>
      _EditAcademicWorkDialogState();
}

class _EditAcademicWorkDialogState
    extends ConsumerState<_EditAcademicWorkDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController(text: widget.work.title);
  late final _descriptionController = TextEditingController(
    text: widget.work.description ?? '',
  );
  late DateTime _assignedDate = widget.work.assignedDate;
  late DateTime _dueDate = widget.work.dueDate;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickAssignedDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _assignedDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) setState(() => _assignedDate = picked);
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate.isBefore(_assignedDate) ? _assignedDate : _dueDate,
      firstDate: _assignedDate,
      lastDate: DateTime(_assignedDate.year + 1),
    );
    if (picked != null) setState(() => _dueDate = picked);
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
          .read(academicWorkControllerProvider)
          .update(
            existing: widget.work,
            title: _titleController.text,
            description: _descriptionController.text,
            assignedDate: _assignedDate,
            dueDate: _dueDate,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on AcademicWorkFailure catch (failure) {
      setState(() => _errorMessage = failure.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                AppTextField(
                  controller: _titleController,
                  label: 'Title',
                  enabled: !_isSubmitting,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Title is required'
                      : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _descriptionController,
                  label: 'Description / instructions (optional)',
                  enabled: !_isSubmitting,
                ),
                const SizedBox(height: AppSpacing.sm),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Assigned date: ${dateKey(_assignedDate)}'),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: _isSubmitting ? null : _pickAssignedDate,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Due date: ${dateKey(_dueDate)}'),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: _isSubmitting ? null : _pickDueDate,
                ),
              ],
            ),
          ),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
