import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../academics/data/academics_repositories.dart';
import '../../batches/data/batch_repository.dart';
import '../application/notice_controller.dart';
import '../data/notice.dart';

/// New notice creation, cascading Title -> Message -> Type -> Audience ->
/// (Class/Batch only when the audience is students/parents) -> Publish/
/// Save (Set 17 section 7). Admin-only.
Future<void> showCreateNoticeDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const _CreateNoticeDialog(),
  );
}

class _CreateNoticeDialog extends ConsumerStatefulWidget {
  const _CreateNoticeDialog();

  @override
  ConsumerState<_CreateNoticeDialog> createState() => _CreateNoticeDialogState();
}

class _CreateNoticeDialogState extends ConsumerState<_CreateNoticeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _otherTypeController = TextEditingController();

  NoticeType _type = NoticeType.general;
  NoticeAudience _audience = NoticeAudience.all;
  NoticeScope _scope = NoticeScope.institute;
  String? _sessionId;
  String? _classId;
  String? _batchId;
  DateTime? _expiresAt;
  NoticeStatus _status = NoticeStatus.published;
  bool _isPublic = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _audienceIsScopable =>
      _audience == NoticeAudience.students || _audience == NoticeAudience.parents;

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
    if (_audienceIsScopable && _scope != NoticeScope.institute && _classId == null) {
      setState(() => _errorMessage = 'Select a class.');
      return;
    }
    if (_audienceIsScopable && _scope == NoticeScope.byBatch && _batchId == null) {
      setState(() => _errorMessage = 'Select a batch.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(noticeControllerProvider).create(
        title: _titleController.text,
        message: _messageController.text,
        type: _type,
        otherTypeLabel: _type == NoticeType.other ? _otherTypeController.text : null,
        audience: _audience,
        scope: _audienceIsScopable ? _scope : NoticeScope.institute,
        academicSessionId: _sessionId,
        classId: _audienceIsScopable ? _classId : null,
        batchId: _audienceIsScopable && _scope == NoticeScope.byBatch ? _batchId : null,
        expiresAt: _expiresAt,
        status: _status,
        isPublic: _isPublic,
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
    final sessionsAsync = ref.watch(allAcademicSessionsProvider);
    final classesAsync = ref.watch(activeSchoolClassesProvider);
    final batchesAsync = ref.watch(activeBatchesProvider);

    return AlertDialog(
      title: const Text('New notice'),
      content: SizedBox(
        width: 420,
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
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                AppTextField(
                  controller: _titleController,
                  label: 'Title *',
                  enabled: !_isSubmitting,
                  validator: (value) =>
                      Validators.required(value, message: 'Title is required'),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _messageController,
                  label: 'Message *',
                  enabled: !_isSubmitting,
                  validator: (value) =>
                      Validators.required(value, message: 'Message is required'),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<NoticeType>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Type *'),
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
                    label: 'Describe the type *',
                    enabled: !_isSubmitting,
                    validator: (value) =>
                        Validators.required(value, message: 'Enter a label for this type'),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<NoticeAudience>(
                  initialValue: _audience,
                  decoration: const InputDecoration(labelText: 'Audience *'),
                  items: NoticeAudience.values
                      .map((audience) => DropdownMenuItem(value: audience, child: Text(audience.label)))
                      .toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (value) => setState(() {
                          _audience = value ?? _audience;
                          _scope = NoticeScope.institute;
                          _classId = null;
                          _batchId = null;
                        }),
                ),
                if (_audienceIsScopable) ...[
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<NoticeScope>(
                    initialValue: _scope,
                    decoration: const InputDecoration(labelText: 'Reach'),
                    items: NoticeScope.values
                        .map((scope) => DropdownMenuItem(value: scope, child: Text(scope.label)))
                        .toList(),
                    onChanged: _isSubmitting
                        ? null
                        : (value) => setState(() {
                            _scope = value ?? _scope;
                            _classId = null;
                            _batchId = null;
                          }),
                  ),
                ],
                if (_audienceIsScopable && _scope != NoticeScope.institute) ...[
                  const SizedBox(height: AppSpacing.sm),
                  sessionsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (error, stackTrace) => const SizedBox.shrink(),
                    data: (sessions) => DropdownButtonFormField<String>(
                      initialValue: _sessionId,
                      decoration: const InputDecoration(
                        labelText: 'Academic session (for reference)',
                      ),
                      items: [
                        for (final session in sessions)
                          DropdownMenuItem(value: session.sessionId, child: Text(session.name)),
                      ],
                      onChanged: _isSubmitting
                          ? null
                          : (value) => setState(() => _sessionId = value),
                    ),
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
                          DropdownMenuItem(value: schoolClass.classId, child: Text(schoolClass.name)),
                      ],
                      onChanged: _isSubmitting
                          ? null
                          : (value) => setState(() {
                              _classId = value;
                              _batchId = null;
                            }),
                      validator: (value) => value == null ? 'Select a class' : null,
                    ),
                  ),
                ],
                if (_audienceIsScopable && _scope == NoticeScope.byBatch) ...[
                  const SizedBox(height: AppSpacing.sm),
                  batchesAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (error, stackTrace) => const SizedBox.shrink(),
                    data: (batches) {
                      final matching = _classId == null
                          ? const []
                          : batches.where((b) => b.classId == _classId).toList();
                      if (_classId == null) {
                        return const Text('Select a class to see matching batches.');
                      }
                      if (matching.isEmpty) {
                        return Text(
                          'No active batches for this class.',
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        );
                      }
                      return DropdownButtonFormField<String>(
                        key: ValueKey('batch-$_classId'),
                        initialValue: matching.any((b) => b.batchId == _batchId) ? _batchId : null,
                        decoration: const InputDecoration(labelText: 'Batch *'),
                        items: [
                          for (final batch in matching)
                            DropdownMenuItem(value: batch.batchId, child: Text(batch.name)),
                        ],
                        onChanged: _isSubmitting
                            ? null
                            : (value) => setState(() => _batchId = value),
                        validator: (value) => value == null ? 'Select a batch' : null,
                      );
                    },
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _expiresAt == null
                        ? 'Expiry (optional)'
                        : 'Expires: ${dateKey(_expiresAt!)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_expiresAt != null)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _isSubmitting ? null : () => setState(() => _expiresAt = null),
                        ),
                      const Icon(Icons.calendar_today_outlined),
                    ],
                  ),
                  onTap: _isSubmitting ? null : _pickExpiry,
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<NoticeStatus>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    for (final status in [NoticeStatus.draft, NoticeStatus.published])
                      DropdownMenuItem(value: status, child: Text(status.label)),
                  ],
                  onChanged: _isSubmitting
                      ? null
                      : (value) => setState(() => _status = value ?? _status),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show on public website'),
                  subtitle: const Text(
                    'Visible to visitors without signing in, once published.',
                  ),
                  value: _isPublic,
                  onChanged: _isSubmitting
                      ? null
                      : (value) => setState(() => _isPublic = value),
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
