import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/data/user_account.dart';
import '../../batches/data/batch_repository.dart';
import '../../student/data/student_profile.dart';
import '../../student/data/student_repository.dart';
import '../../teacher_assignments/data/teacher_assignment_repository.dart';
import '../application/work_completion_controller.dart';
import '../data/academic_work.dart';
import '../data/academic_work_repository.dart';
import '../data/work_completion.dart';
import '../data/work_completion_repository.dart';
import 'work_completion_style.dart';

enum _Filter {
  all('All'),
  completed('Completed'),
  incomplete('Incomplete'),
  notCompleted('Not completed'),
  notMarked('Not marked');

  const _Filter(this.label);

  final String label;

  bool matches(WorkCompletionStatus? status) => switch (this) {
    _Filter.all => true,
    _Filter.completed => status == WorkCompletionStatus.completed,
    _Filter.incomplete => status == WorkCompletionStatus.incomplete,
    _Filter.notCompleted => status == WorkCompletionStatus.notCompleted,
    _Filter.notMarked => status == null,
  };
}

/// Who did what for one homework/assignment: every active student of its
/// batch with their completed / incomplete / not completed mark. Teachers
/// whose assignment covers the item (and admin) can mark and re-mark;
/// anyone else sees it read-only. One Save writes only the changed rows
/// and pops a colored message up on those students' apps.
class WorkCompletionScreen extends ConsumerWidget {
  const WorkCompletionScreen({super.key, required this.workId});

  final String workId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workAsync = ref.watch(academicWorkByIdProvider(workId));

    return Scaffold(
      appBar: AppBar(title: const Text('Student status')),
      body: SafeArea(
        child: workAsync.when(
          loading: () => const LoadingView(),
          error: (error, stackTrace) => ErrorView(
            message: 'Unable to load this item. Please try again.\n$error',
          ),
          data: (work) {
            if (work == null) return const ErrorView(message: 'Not found.');
            return _Body(work: work);
          },
        ),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.work});

  final AcademicWork work;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  final Map<String, CompletionEntry> _staged = {};
  _Filter _filter = _Filter.all;
  bool _saving = false;

  WorkCompletionStatus? _statusOf(
    String uid,
    Map<String, WorkCompletion> existing,
  ) => _staged[uid]?.status ?? existing[uid]?.status;

  String? _remarkOf(String uid, Map<String, WorkCompletion> existing) =>
      _staged.containsKey(uid) ? _staged[uid]!.remark : existing[uid]?.remark;

  String? _blankToNull(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();

  bool _isChange(WorkCompletion? existing, CompletionEntry entry) {
    if (existing == null) return true;
    return existing.status != entry.status ||
        _blankToNull(existing.remark) != _blankToNull(entry.remark);
  }

  void _stage(
    String uid,
    CompletionEntry entry,
    Map<String, WorkCompletion> existing,
  ) {
    setState(() {
      // Setting a row back to what's already saved is not a change.
      if (_isChange(existing[uid], entry)) {
        _staged[uid] = entry;
      } else {
        _staged.remove(uid);
      }
    });
  }

  Future<void> _editRemark(
    StudentProfile student,
    WorkCompletionStatus status,
    Map<String, WorkCompletion> existing,
  ) async {
    final controller = TextEditingController(
      text: _remarkOf(student.uid, existing) ?? '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remark for ${student.name}'),
        content: AppTextField(
          controller: controller,
          label: 'Remark (optional, shown to the student)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          AppButton(
            label: 'Done',
            onPressed: () => Navigator.of(context).pop(controller.text),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    _stage(
      student.uid,
      CompletionEntry(status: status, remark: _blankToNull(result)),
      existing,
    );
  }

  Future<void> _save(Map<String, WorkCompletion> existing) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final count = await ref
          .read(workCompletionControllerProvider)
          .saveBulk(
            work: widget.work,
            entries: Map.of(_staged),
            existing: existing,
          );
      if (!mounted) return;
      setState(_staged.clear);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            count == 0
                ? 'Nothing to save.'
                : 'Saved - $count student${count == 1 ? '' : 's'} notified.',
          ),
        ),
      );
    } on WorkCompletionFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final work = widget.work;
    final account = ref.watch(currentUserAccountProvider).valueOrNull;
    final isAdmin = account?.role == UserRole.admin;
    final isTeacher = account?.role == UserRole.teacher;
    final teacherCanMark = isTeacher && account != null
        ? teacherCanOperateOn(
            ref.watch(ownTeacherAssignmentsProvider(account.uid)).valueOrNull ??
                const [],
            academicSessionId: work.academicSessionId,
            classId: work.classId,
            batchId: work.batchId,
            subjectId: work.subjectId,
          )
        : false;
    final isDraft = work.status == AcademicWorkStatus.draft;
    final canEdit = (isAdmin || teacherCanMark) && !isDraft;

    final studentsAsync = ref.watch(allStudentsProvider);
    final completionsAsync = ref.watch(
      workCompletionsForWorkProvider(work.workId),
    );
    final batchName = ref
        .watch(allBatchesProvider)
        .valueOrNull
        ?.where((b) => b.batchId == work.batchId)
        .firstOrNull
        ?.name;

    if (studentsAsync.isLoading || completionsAsync.isLoading) {
      return const LoadingView();
    }
    final error = studentsAsync.error ?? completionsAsync.error;
    if (error != null) {
      return ErrorView(
        message: 'Unable to load student status. Please try again.\n$error',
      );
    }

    final roster = [
      for (final student in studentsAsync.value ?? const <StudentProfile>[])
        if (student.active && student.batchId == work.batchId) student,
    ];
    final existing = {
      for (final completion
          in completionsAsync.value ?? const <WorkCompletion>[])
        completion.studentUid: completion,
    };

    var completed = 0;
    var incomplete = 0;
    var notCompleted = 0;
    var notMarked = 0;
    for (final student in roster) {
      switch (_statusOf(student.uid, existing)) {
        case WorkCompletionStatus.completed:
          completed++;
        case WorkCompletionStatus.incomplete:
          incomplete++;
        case WorkCompletionStatus.notCompleted:
          notCompleted++;
        case null:
          notMarked++;
      }
    }

    final visible = [
      for (final student in roster)
        if (_filter.matches(_statusOf(student.uid, existing))) student,
    ];
    final pendingChanges = _staged.length;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          work.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${work.type.label} · ${work.subject}'
                          '${batchName == null ? '' : ' · $batchName'}'
                          ' · Due ${dateKey(work.dueDate)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        WorkCompletionSummaryRow(
                          summary: WorkCompletionSummary(
                            completed: completed,
                            incomplete: incomplete,
                            notCompleted: notCompleted,
                            notMarked: notMarked,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isDraft)
                    const _Notice(
                      'This item is still a draft. Publish it to mark '
                      'student status.',
                    )
                  else if (!canEdit)
                    const _Notice(
                      'You can view, but not change, student status for '
                      'this item.',
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final filter in _Filter.values) ...[
                          ChoiceChip(
                            label: Text(filter.label),
                            selected: _filter == filter,
                            onSelected: (_) => setState(() => _filter = filter),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                        ],
                      ],
                    ),
                  ),
                  if (canEdit && notMarked > 0)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          for (final student in roster) {
                            if (_statusOf(student.uid, existing) == null) {
                              _stage(
                                student.uid,
                                const CompletionEntry(
                                  status: WorkCompletionStatus.completed,
                                ),
                                existing,
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.done_all, size: 18),
                        label: const Text('Mark remaining as completed'),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  if (roster.isEmpty)
                    const SizedBox(
                      height: 200,
                      child: EmptyView(
                        message: 'No active students in this batch.',
                      ),
                    )
                  else if (visible.isEmpty)
                    const SizedBox(
                      height: 160,
                      child: EmptyView(
                        message: 'No students match this filter.',
                      ),
                    )
                  else
                    for (final student in visible)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _StudentRow(
                          student: student,
                          status: _statusOf(student.uid, existing),
                          remark: _remarkOf(student.uid, existing),
                          markedAt: existing[student.uid]?.markedAt,
                          isStaged: _staged.containsKey(student.uid),
                          canEdit: canEdit,
                          onSelect: (status) => _stage(
                            student.uid,
                            CompletionEntry(
                              status: status,
                              remark: _remarkOf(student.uid, existing),
                            ),
                            existing,
                          ),
                          onEditRemark: () {
                            final status = _statusOf(student.uid, existing);
                            if (status != null) {
                              _editRemark(student, status, existing);
                            }
                          },
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
        if (canEdit)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: AppButton(
              label: pendingChanges == 0
                  ? 'Save'
                  : 'Save ($pendingChanges change${pendingChanges == 1 ? '' : 's'})',
              isLoading: _saving,
              onPressed: pendingChanges == 0 ? null : () => _save(existing),
            ),
          ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceSunken,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(message, style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.student,
    required this.status,
    required this.remark,
    required this.markedAt,
    required this.isStaged,
    required this.canEdit,
    required this.onSelect,
    required this.onEditRemark,
  });

  final StudentProfile student;
  final WorkCompletionStatus? status;
  final String? remark;
  final DateTime? markedAt;
  final bool isStaged;
  final bool canEdit;
  final ValueChanged<WorkCompletionStatus> onSelect;
  final VoidCallback onEditRemark;

  @override
  Widget build(BuildContext context) {
    final hasRemark = remark != null && remark!.isNotEmpty;
    final meta = [
      student.admissionNumber,
      if (isStaged)
        'Unsaved change'
      else if (markedAt != null)
        'Marked ${dateKey(markedAt!)}',
    ].where((part) => part.isNotEmpty).join(' · ');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (meta.isNotEmpty)
                      Text(
                        meta,
                        style: TextStyle(
                          fontSize: 12,
                          color: isStaged
                              ? AppColors.onWarningSoft
                              : AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (!canEdit)
                status == null
                    ? const Text(
                        'Not marked',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      )
                    : WorkCompletionChip(status: status!),
            ],
          ),
          if (canEdit) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                for (final option in WorkCompletionStatus.values) ...[
                  if (option != WorkCompletionStatus.completed)
                    const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _ChoiceButton(
                      status: option,
                      selected: status == option,
                      onTap: () => onSelect(option),
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (hasRemark)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Remark: $remark',
                style: const TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          if (canEdit && status != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onEditRemark,
                icon: const Icon(Icons.edit_note, size: 18),
                label: Text(hasRemark ? 'Edit remark' : 'Add remark'),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final WorkCompletionStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = toneFor(status);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? tone.background : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? tone.border : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                tone.icon,
                size: 16,
                color: selected ? tone.foreground : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                status.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? tone.foreground : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
