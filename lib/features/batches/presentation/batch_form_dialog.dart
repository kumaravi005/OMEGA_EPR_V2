import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../academics/data/academics_repositories.dart';
import '../../academics/data/board.dart';
import '../application/batch_controller.dart';
import '../data/batch.dart';

void showBatchFormDialog(BuildContext context, {Batch? existing}) {
  showDialog<void>(
    context: context,
    builder: (context) => _BatchFormDialog(existing: existing),
  );
}

class _BatchFormDialog extends ConsumerStatefulWidget {
  const _BatchFormDialog({this.existing});

  final Batch? existing;

  @override
  ConsumerState<_BatchFormDialog> createState() => _BatchFormDialogState();
}

class _BatchFormDialogState extends ConsumerState<_BatchFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final _codeController = TextEditingController(
    text: widget.existing?.batchCode ?? '',
  );
  late final _descriptionController = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late final _boardCustomController = TextEditingController(
    text: widget.existing?.boardCustomText ?? '',
  );
  late final _monthlyController = TextEditingController(
    text: widget.existing?.standardMonthlyFee.toStringAsFixed(0) ?? '',
  );
  late final _installmentController = TextEditingController(
    text: widget.existing?.standardInstallmentFee.toStringAsFixed(0) ?? '',
  );

  String? _sessionId;
  String? _classId;
  String? _boardId;
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _initializedSelection = false;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    _boardCustomController.dispose();
    _monthlyController.dispose();
    _installmentController.dispose();
    super.dispose();
  }

  /// Merges the given master-data list with the batch's currently
  /// selected id (even if that entry has since been deactivated), so
  /// editing an older batch never silently drops its existing
  /// session/class/board from the dropdown.
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

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    if (_sessionId == null || _classId == null) {
      setState(() => _errorMessage = 'Select an academic session and a class.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final monthly = double.parse(_monthlyController.text);
    final installment = double.parse(_installmentController.text);

    try {
      final controller = ref.read(batchControllerProvider);
      if (widget.existing == null) {
        await controller.createBatch(
          name: _nameController.text,
          batchCode: _codeController.text,
          description: _descriptionController.text,
          academicSessionId: _sessionId!,
          classId: _classId!,
          boardId: _boardId,
          boardCustomText: _boardCustomController.text,
          standardMonthlyFee: monthly,
          standardInstallmentFee: installment,
        );
      } else {
        await controller.updateBatch(
          widget.existing!,
          name: _nameController.text,
          batchCode: _codeController.text,
          description: _descriptionController.text,
          academicSessionId: _sessionId!,
          classId: _classId!,
          boardId: _boardId,
          boardCustomText: _boardCustomController.text,
          standardMonthlyFee: monthly,
          standardInstallmentFee: installment,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on BatchFailure catch (failure) {
      setState(() => _errorMessage = failure.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeSessionsAsync = ref.watch(allAcademicSessionsProvider);
    final activeClassesAsync = ref.watch(activeSchoolClassesProvider);
    final allClassesAsync = ref.watch(allSchoolClassesProvider);
    final activeBoardsAsync = ref.watch(activeBoardsProvider);
    final allBoardsAsync = ref.watch(allBoardsProvider);

    // Default to the active session/class on first build once data has
    // loaded, without clobbering a user's in-progress selection.
    if (!_initializedSelection) {
      final existingSessionId = widget.existing?.academicSessionId;
      final existingClassId = widget.existing?.classId;
      _sessionId = (existingSessionId == null || existingSessionId.isEmpty)
          ? null
          : existingSessionId;
      _classId = (existingClassId == null || existingClassId.isEmpty)
          ? null
          : existingClassId;
      _boardId = widget.existing?.boardId;
      if (_sessionId == null && widget.existing == null) {
        final sessions = activeSessionsAsync.valueOrNull;
        if (sessions != null) {
          _sessionId = sessions.where((s) => s.isActive).firstOrNull?.sessionId;
          _initializedSelection = true;
        }
      } else {
        _initializedSelection = true;
      }
    }

    final selectedBoard = (allBoardsAsync.valueOrNull ?? const <Board>[])
        .where((b) => b.boardId == _boardId)
        .firstOrNull;
    final isOthersBoard = selectedBoard?.name == 'Others';

    return AlertDialog(
      title: Text(widget.existing == null ? 'New batch' : 'Edit batch'),
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                AppTextField(
                  controller: _nameController,
                  label: 'Batch name',
                  hintText: 'e.g. Class 5 Morning',
                  enabled: !_isSubmitting,
                  validator: (value) => Validators.required(
                    value,
                    message: 'Batch name is required',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                activeSessionsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (error, stackTrace) => const SizedBox.shrink(),
                  data: (sessions) => DropdownButtonFormField<String>(
                    initialValue: _sessionId,
                    decoration: const InputDecoration(
                      labelText: 'Academic session *',
                    ),
                    items: [
                      for (final session in _selectableOptions(
                        sessions,
                        sessions,
                        (s) => s.sessionId,
                        _sessionId,
                      ))
                        DropdownMenuItem(
                          value: session.sessionId,
                          child: Text(session.name),
                        ),
                    ],
                    onChanged: _isSubmitting
                        ? null
                        : (value) => setState(() => _sessionId = value),
                    validator: (value) =>
                        value == null ? 'Select an academic session' : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                activeClassesAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (error, stackTrace) => const SizedBox.shrink(),
                  data: (activeClasses) => DropdownButtonFormField<String>(
                    initialValue: _classId,
                    decoration: const InputDecoration(labelText: 'Class *'),
                    items: [
                      for (final schoolClass in _selectableOptions(
                        activeClasses,
                        allClassesAsync.valueOrNull ?? activeClasses,
                        (c) => c.classId,
                        _classId,
                      ))
                        DropdownMenuItem(
                          value: schoolClass.classId,
                          child: Text(schoolClass.name),
                        ),
                    ],
                    onChanged: _isSubmitting
                        ? null
                        : (value) => setState(() => _classId = value),
                    validator: (value) =>
                        value == null ? 'Select a class' : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                activeBoardsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (error, stackTrace) => const SizedBox.shrink(),
                  data: (activeBoards) => DropdownButtonFormField<String?>(
                    initialValue: _boardId,
                    decoration: const InputDecoration(
                      labelText: 'Board (optional)',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Not applicable'),
                      ),
                      for (final board in _selectableOptions(
                        activeBoards,
                        allBoardsAsync.valueOrNull ?? activeBoards,
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
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _codeController,
                  label: 'Batch code (optional)',
                  enabled: !_isSubmitting,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _descriptionController,
                  label: 'Description (optional)',
                  enabled: !_isSubmitting,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Fee configuration',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _monthlyController,
                  label: 'Standard monthly fee',
                  enabled: !_isSubmitting,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) =>
                      Validators.amount(value, label: 'Standard monthly fee'),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _installmentController,
                  label: 'Standard installment/course fee',
                  enabled: !_isSubmitting,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) => Validators.amount(
                    value,
                    label: 'Standard installment/course fee',
                  ),
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
