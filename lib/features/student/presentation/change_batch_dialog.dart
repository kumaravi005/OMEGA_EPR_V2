import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../academics/data/academics_repositories.dart';
import '../../academics/data/board.dart';
import '../../auth/application/auth_providers.dart';
import '../../batches/data/batch.dart';
import '../../batches/data/batch_repository.dart';
import '../../batches/data/installment_schedule_item.dart';
import '../application/student_form_controller.dart';
import '../data/student_profile.dart';
import 'installment_entry_dialog.dart';

/// Moves a student to a different academic session/class/batch (and
/// re-agrees their fee) without ever rewriting the admission record it
/// supersedes (Set 11 spec section 20) - see
/// `StudentFormController.changeBatch`.
void showChangeBatchDialog(BuildContext context, {required StudentProfile student}) {
  showDialog<void>(
    context: context,
    builder: (context) => _ChangeBatchDialog(student: student),
  );
}

class _ChangeBatchDialog extends ConsumerStatefulWidget {
  const _ChangeBatchDialog({required this.student});

  final StudentProfile student;

  @override
  ConsumerState<_ChangeBatchDialog> createState() =>
      _ChangeBatchDialogState();
}

class _ChangeBatchDialogState extends ConsumerState<_ChangeBatchDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _boardCustomController = TextEditingController(
    text: widget.student.boardCustomText ?? '',
  );
  late final _finalFeeController = TextEditingController();
  final _feeReasonController = TextEditingController();

  String? _sessionId;
  String? _classId;
  String? _batchId;
  String? _boardId;
  double _standardFee = 0;
  PaymentPlan _paymentPlan = PaymentPlan.monthly;
  final List<InstallmentScheduleItem> _installments = [];

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _boardId = widget.student.boardId;
    _paymentPlan = widget.student.paymentPlan;
  }

  @override
  void dispose() {
    _boardCustomController.dispose();
    _finalFeeController.dispose();
    _feeReasonController.dispose();
    super.dispose();
  }

  void _recomputeStandardFee(List<Batch> matching) {
    final batch = matching.where((b) => b.batchId == _batchId).firstOrNull;
    if (batch == null) return;
    setState(() {
      _standardFee = batch.standardFeeFor(
        isInstallment: _paymentPlan == PaymentPlan.installment,
      );
      _finalFeeController.text = _standardFee.toStringAsFixed(0);
      if (batch.boardId != null) _boardId = batch.boardId;
    });
  }

  Future<void> _addInstallment() async {
    final item = await showInstallmentEntryDialog(context);
    if (item != null) setState(() => _installments.add(item));
  }

  Future<void> _submit(List<Board> boards) async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    if (_sessionId == null || _classId == null || _batchId == null) {
      setState(
        () => _errorMessage = 'Select an academic session, class and batch.',
      );
      return;
    }

    final finalFee = double.parse(_finalFeeController.text);
    if (finalFee != _standardFee && _feeReasonController.text.trim().isEmpty) {
      setState(
        () => _errorMessage =
            'A remark is required when the final fee differs from the standard fee.',
      );
      return;
    }
    if (_paymentPlan == PaymentPlan.installment && _installments.isEmpty) {
      setState(() => _errorMessage = 'Add at least one installment.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final sessions = ref.read(allAcademicSessionsProvider).valueOrNull ?? [];
      final classes = ref.read(activeSchoolClassesProvider).valueOrNull ?? [];
      final sessionName =
          sessions.where((s) => s.sessionId == _sessionId).firstOrNull?.name ??
          '';
      final className =
          classes.where((c) => c.classId == _classId).firstOrNull?.name ?? '';
      final selectedBoard = boards.where((b) => b.boardId == _boardId).firstOrNull;
      final boardDisplayName = selectedBoard == null
          ? ''
          : (selectedBoard.name == 'Others'
                ? _boardCustomController.text.trim()
                : selectedBoard.name);
      final adminUid = ref.read(currentUserAccountProvider).valueOrNull?.uid;
      final feeReason = _feeReasonController.text.trim().isEmpty
          ? null
          : _feeReasonController.text;

      await ref
          .read(studentFormControllerProvider)
          .changeBatch(
            existing: widget.student,
            academicSessionId: _sessionId!,
            academicSessionName: sessionName,
            classId: _classId!,
            className: className,
            batchId: _batchId!,
            boardId: _boardId,
            boardCustomText: _boardCustomController.text,
            boardDisplayName: boardDisplayName,
            standardFee: _standardFee,
            finalFee: finalFee,
            feeReason: feeReason,
            paymentPlan: _paymentPlan,
            installments: _installments,
            configuredByUid: adminUid ?? '',
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
    final sessionsAsync = ref.watch(allAcademicSessionsProvider);
    final classesAsync = ref.watch(activeSchoolClassesProvider);
    final batchesAsync = ref.watch(activeBatchesProvider);
    final activeBoardsAsync = ref.watch(activeBoardsProvider);
    final allBoardsAsync = ref.watch(allBoardsProvider);
    final boards = allBoardsAsync.valueOrNull ?? const <Board>[];
    final activeBoards = activeBoardsAsync.valueOrNull ?? const <Board>[];
    final selectedBoard = boards.where((b) => b.boardId == _boardId).firstOrNull;
    final isOthersBoard = selectedBoard?.name == 'Others';
    final discount =
        _standardFee -
        (double.tryParse(_finalFeeController.text) ?? _standardFee);

    return AlertDialog(
      title: const Text('Change batch'),
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
                sessionsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (error, stackTrace) => const SizedBox.shrink(),
                  data: (sessions) => DropdownButtonFormField<String>(
                    initialValue: _sessionId,
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
                    onChanged: _isSubmitting
                        ? null
                        : (value) => setState(() {
                            _sessionId = value;
                            _batchId = null;
                            _standardFee = 0;
                          }),
                    validator: (value) =>
                        value == null ? 'Select an academic session' : null,
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
                        DropdownMenuItem(
                          value: schoolClass.classId,
                          child: Text(schoolClass.name),
                        ),
                    ],
                    onChanged: _isSubmitting
                        ? null
                        : (value) => setState(() {
                            _classId = value;
                            _batchId = null;
                            _standardFee = 0;
                          }),
                    validator: (value) =>
                        value == null ? 'Select a class' : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                batchesAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (error, stackTrace) => const SizedBox.shrink(),
                  data: (batches) {
                    final matching = batchesForSessionAndClass(
                      batches,
                      academicSessionId: _sessionId,
                      classId: _classId,
                    );
                    if (_sessionId == null || _classId == null) {
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
                      key: ValueKey('batch-$_sessionId-$_classId'),
                      initialValue: matching.any((b) => b.batchId == _batchId)
                          ? _batchId
                          : null,
                      decoration: const InputDecoration(labelText: 'Batch *'),
                      items: [
                        for (final batch in matching)
                          DropdownMenuItem(
                            value: batch.batchId,
                            child: Text(batch.name),
                          ),
                      ],
                      onChanged: _isSubmitting
                          ? null
                          : (value) {
                              setState(() => _batchId = value);
                              _recomputeStandardFee(matching);
                            },
                      validator: (value) =>
                          value == null ? 'Select a batch' : null,
                    );
                  },
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
                      for (final board in activeBoards)
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
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Fee agreement',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Builder(
                  builder: (context) {
                    final batches =
                        batchesAsync.valueOrNull ?? const <Batch>[];
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
                          : (value) {
                              if (value == null) return;
                              setState(() => _paymentPlan = value);
                              _recomputeStandardFee(matching);
                            },
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
                  label: 'Remark (required if fee differs from standard)',
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
                            : () => setState(() => _installments.remove(item)),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: _isSubmitting ? null : _addInstallment,
                    icon: const Icon(Icons.add),
                    label: const Text('Add installment'),
                  ),
                ],
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
        AppButton(
          label: 'Save',
          isLoading: _isSubmitting,
          onPressed: () => _submit(boards),
        ),
      ],
    );
  }
}
