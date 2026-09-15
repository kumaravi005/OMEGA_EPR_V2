import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../academics/data/academic_session.dart';
import '../../academics/data/academics_repositories.dart';
import '../../academics/data/school_class.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/data/user_account.dart';
import '../../batches/data/batch.dart';
import '../../batches/data/batch_repository.dart';
import '../application/notice_controller.dart';
import '../data/notice.dart';
import '../data/notice_read_state.dart';
import '../data/notice_repository.dart';

/// Notice Information / Targeting / Record Information, plus edit/
/// publish/close controls for admin only (Set 17 section 10) - everyone
/// else (teacher, student/parent) gets the same layout read-only, and
/// opening this screen marks the notice read for them (section 14: "do
/// not mark read merely because it appeared in the list... opening it
/// should mark it read"). Mirrors `AcademicWorkDetailsScreen`'s
/// one-screen-for-every-role shape.
///
/// Never shows a raw session/class/batch id (section 24) - only the
/// resolved display name, exactly like `AcademicWorkDetailsScreen`.
class NoticeDetailsScreen extends ConsumerStatefulWidget {
  const NoticeDetailsScreen({super.key, required this.noticeId});

  final String noticeId;

  @override
  ConsumerState<NoticeDetailsScreen> createState() => _NoticeDetailsScreenState();
}

class _NoticeDetailsScreenState extends ConsumerState<NoticeDetailsScreen> {
  bool _markedRead = false;

  void _maybeMarkRead(Notice notice, bool isAdmin) {
    if (_markedRead || isAdmin) return;
    _markedRead = true;
    Future.microtask(() => markNoticeRead(ref, notice.noticeId));
  }

  @override
  Widget build(BuildContext context) {
    final noticeAsync = ref.watch(noticeByIdProvider(widget.noticeId));
    final isAdmin =
        ref.watch(currentUserAccountProvider).valueOrNull?.role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(title: const Text('Notice')),
      body: SafeArea(
        child: noticeAsync.when(
          loading: () => const LoadingView(),
          error: (error, stackTrace) =>
              ErrorView(message: 'Unable to load this notice. Please try again.\n$error'),
          data: (notice) {
            if (notice == null) {
              return const ErrorView(message: 'Not found.');
            }
            _maybeMarkRead(notice, isAdmin);
            return _DetailsBody(notice: notice, isAdmin: isAdmin);
          },
        ),
      ),
    );
  }
}

class _DetailsBody extends ConsumerWidget {
  const _DetailsBody({required this.notice, required this.isAdmin});

  final Notice notice;
  final bool isAdmin;

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(NoticeController controller) action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action(ref.read(noticeControllerProvider));
    } on NoticeFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expired = notice.isExpired(DateTime.now());

    if (!isAdmin) {
      // Teacher/student/parent/public: just what a reader actually needs
      // - heading, body, and when it was published - no boxed sections,
      // no internal type/targeting/record-keeping detail.
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(notice.title, style: Theme.of(context).textTheme.headlineSmall),
              if (expired && notice.status == NoticeStatus.published) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Expired',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(notice.message, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Published ${dateKey(notice.publishedAt ?? notice.createdAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    // Admin only from here on - resolve the display names the
    // "Targeting" card below needs (admin is always signed in, so these
    // queries are always safe to issue).
    final sessions = ref.watch(allAcademicSessionsProvider).valueOrNull ?? const <AcademicSession>[];
    final classes = ref.watch(allSchoolClassesProvider).valueOrNull ?? const <SchoolClass>[];
    final batches = ref.watch(allBatchesProvider).valueOrNull ?? const <Batch>[];
    final sessionName = sessions.where((s) => s.sessionId == notice.academicSessionId).firstOrNull?.name;
    final className = classes.where((c) => c.classId == notice.classId).firstOrNull?.name;
    final batchName = batches.where((b) => b.batchId == notice.batchId).firstOrNull?.name;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(notice.title, style: Theme.of(context).textTheme.headlineSmall),
                ),
                Chip(label: Text(notice.status.label)),
              ],
            ),
            if (expired && notice.status == NoticeStatus.published)
              Text(
                'Expired',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notice information', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(
                    label: 'Type',
                    value: notice.type == NoticeType.other
                        ? (notice.otherTypeLabel ?? notice.type.label)
                        : notice.type.label,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(notice.message, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Targeting', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(label: 'Audience', value: notice.audience.label),
                  if (notice.scope != NoticeScope.institute) ...[
                    if (sessionName != null) _InfoRow(label: 'Session', value: sessionName),
                    if (className != null) _InfoRow(label: 'Class', value: className),
                    if (batchName != null) _InfoRow(label: 'Batch', value: batchName),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Record information', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(label: 'Created', value: dateKey(notice.createdAt)),
                  if (notice.publishedAt != null)
                    _InfoRow(label: 'Published', value: dateKey(notice.publishedAt!)),
                  _InfoRow(label: 'Updated', value: dateKey(notice.updatedAt)),
                  if (notice.expiresAt != null)
                    _InfoRow(label: 'Expires', value: dateKey(notice.expiresAt!)),
                ],
              ),
            ),
            if (isAdmin) ...[
              const SizedBox(height: AppSpacing.md),
              AppCard(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show on public website'),
                  subtitle: const Text(
                    'Visible to visitors without signing in, once published.',
                  ),
                  value: notice.isPublic,
                  onChanged: (value) =>
                      _act(context, ref, (c) => c.setPublicVisibility(notice, value)),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (notice.status == NoticeStatus.draft) ...[
                AppButton(
                  label: 'Edit',
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => _EditNoticeDialog(notice: notice),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Publish',
                  onPressed: () => _act(context, ref, (c) => c.publish(notice)),
                ),
              ],
              if (notice.status == NoticeStatus.published)
                AppButton(
                  label: 'Close',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => _act(context, ref, (c) => c.close(notice)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EditNoticeDialog extends ConsumerStatefulWidget {
  const _EditNoticeDialog({required this.notice});

  final Notice notice;

  @override
  ConsumerState<_EditNoticeDialog> createState() => _EditNoticeDialogState();
}

class _EditNoticeDialogState extends ConsumerState<_EditNoticeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController(text: widget.notice.title);
  late final _messageController = TextEditingController(text: widget.notice.message);
  late final _otherTypeController = TextEditingController(text: widget.notice.otherTypeLabel ?? '');
  late NoticeType _type = widget.notice.type;
  late DateTime? _expiresAt = widget.notice.expiresAt;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _otherTypeController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(noticeControllerProvider).edit(
        existing: widget.notice,
        title: _titleController.text,
        message: _messageController.text,
        type: _type,
        otherTypeLabel: _type == NoticeType.other ? _otherTypeController.text : null,
        expiresAt: _expiresAt,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on NoticeFailure catch (failure) {
      setState(() => _errorMessage = failure.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit draft'),
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
                  Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  const SizedBox(height: AppSpacing.sm),
                ],
                AppTextField(
                  controller: _titleController,
                  label: 'Title',
                  enabled: !_isSubmitting,
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Title is required' : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _messageController,
                  label: 'Message',
                  enabled: !_isSubmitting,
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Message is required' : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<NoticeType>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: NoticeType.values
                      .map((type) => DropdownMenuItem(value: type, child: Text(type.label)))
                      .toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (value) => setState(() => _type = value ?? _type),
                ),
                if (_type == NoticeType.other) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: _otherTypeController,
                    label: 'Describe the type',
                    enabled: !_isSubmitting,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _expiresAt == null ? 'Expiry (optional)' : 'Expires: ${dateKey(_expiresAt!)}',
                  ),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: _isSubmitting ? null : _pickExpiry,
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
          SizedBox(width: 140, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
