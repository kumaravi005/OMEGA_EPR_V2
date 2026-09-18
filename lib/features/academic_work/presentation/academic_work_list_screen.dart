import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../academics/data/academics_repositories.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/data/user_account.dart';
import '../../batches/data/batch_repository.dart';
import '../../student/data/student_repository.dart';
import '../../teacher/data/teacher_repository.dart';
import '../../teacher_assignments/data/teacher_assignment_repository.dart';
import '../data/academic_work.dart';
import '../data/academic_work_repository.dart';
import '../data/work_completion.dart';
import '../data/work_completion_repository.dart';
import 'create_academic_work_dialog.dart';
import 'work_completion_style.dart';

enum _TypeFilter { all, homework, assignment }

enum _StatusFilter { all, draft, published, closed }

/// Admin/teacher homework & assignments list: search by title, filter by
/// type/session/class/batch/subject/status. Admin always sees the "New"
/// action; a teacher sees it only once they hold at least one active
/// `TeacherAssignment` (Set 22/23 - creation is no longer admin-only, now
/// that assignment-derived authorization exists - see
/// `AcademicWorkController`'s doc comment and
/// `create_academic_work_dialog.dart`). A signed-in teacher's subject
/// filter defaults to their own `TeacherProfile.subjectIds` (Set 16 spec:
/// "teachers should only see academic work relevant to the subjects they
/// are authorized for") - a soft, convenience default they can still
/// change, not a hard security boundary (the read rule already grants
/// any active teacher broad read access, matching the existing tests/
/// attendance precedent - see docs/database-architecture.md).
class AcademicWorkListScreen extends ConsumerStatefulWidget {
  const AcademicWorkListScreen({super.key, required this.basePath});

  final String basePath;

  @override
  ConsumerState<AcademicWorkListScreen> createState() =>
      _AcademicWorkListScreenState();
}

class _AcademicWorkListScreenState
    extends ConsumerState<AcademicWorkListScreen> {
  final _searchController = TextEditingController();
  _TypeFilter _typeFilter = _TypeFilter.all;
  String? _sessionFilter;
  String? _classFilter;
  String? _batchFilter;
  String? _subjectFilter;
  _StatusFilter _statusFilter = _StatusFilter.all;
  bool _defaultedTeacherSubject = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(AcademicWork work) {
    final query = _searchController.text.trim().toLowerCase();
    final matchesQuery =
        query.isEmpty || work.title.toLowerCase().contains(query);
    final matchesType = switch (_typeFilter) {
      _TypeFilter.all => true,
      _TypeFilter.homework => work.type == AcademicWorkType.homework,
      _TypeFilter.assignment => work.type == AcademicWorkType.assignment,
    };
    final matchesSession =
        _sessionFilter == null || work.academicSessionId == _sessionFilter;
    final matchesClass = _classFilter == null || work.classId == _classFilter;
    final matchesBatch = _batchFilter == null || work.batchId == _batchFilter;
    final matchesSubject =
        _subjectFilter == null || work.subjectId == _subjectFilter;
    final matchesStatus = switch (_statusFilter) {
      _StatusFilter.all => true,
      _StatusFilter.draft => work.status == AcademicWorkStatus.draft,
      _StatusFilter.published => work.status == AcademicWorkStatus.published,
      _StatusFilter.closed => work.status == AcademicWorkStatus.closed,
    };
    return matchesQuery &&
        matchesType &&
        matchesSession &&
        matchesClass &&
        matchesBatch &&
        matchesSubject &&
        matchesStatus;
  }

  @override
  Widget build(BuildContext context) {
    final workAsync = ref.watch(allAcademicWorkProvider);
    final completionsByWork = <String, List<WorkCompletion>>{};
    for (final completion
        in ref.watch(allWorkCompletionsProvider).valueOrNull ??
            const <WorkCompletion>[]) {
      (completionsByWork[completion.workId] ??= []).add(completion);
    }
    final studentCountByBatch = <String, int>{};
    for (final student
        in ref.watch(allStudentsProvider).valueOrNull ?? const []) {
      if (student.active) {
        studentCountByBatch[student.batchId] =
            (studentCountByBatch[student.batchId] ?? 0) + 1;
      }
    }
    final sessionsAsync = ref.watch(allAcademicSessionsProvider);
    final classesAsync = ref.watch(allSchoolClassesProvider);
    final batchesAsync = ref.watch(allBatchesProvider);
    final subjectsAsync = ref.watch(allSubjectsProvider);
    final account = ref.watch(currentUserAccountProvider).valueOrNull;
    final isAdmin = account?.role == UserRole.admin;
    final isTeacher = account?.role == UserRole.teacher;

    if (account != null && isTeacher && !_defaultedTeacherSubject) {
      final teacher = ref
          .watch(ownTeacherProfileProvider(account.uid))
          .valueOrNull;
      if (teacher != null) {
        _defaultedTeacherSubject = true;
        if (teacher.subjectIds.length == 1) {
          _subjectFilter = teacher.subjectIds.first;
        }
      }
    }
    final teacherHasActiveAssignment = isTeacher && account != null
        ? (ref.watch(ownTeacherAssignmentsProvider(account.uid)).valueOrNull ??
                  const [])
              .any((a) => a.active)
        : false;

    return Scaffold(
      appBar: AppBar(title: const Text('Homework & Assignments')),
      floatingActionButton: isAdmin || teacherHasActiveAssignment
          ? FloatingActionButton.extended(
              onPressed: () => showCreateAcademicWorkDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('New'),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  AppTextField(
                    controller: _searchController,
                    label: 'Search by title',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SegmentedButton<_TypeFilter>(
                    segments: const [
                      ButtonSegment(value: _TypeFilter.all, label: Text('All')),
                      ButtonSegment(
                        value: _TypeFilter.homework,
                        label: Text('Homework'),
                      ),
                      ButtonSegment(
                        value: _TypeFilter.assignment,
                        label: Text('Assignments'),
                      ),
                    ],
                    selected: {_typeFilter},
                    onSelectionChanged: (selection) =>
                        setState(() => _typeFilter = selection.first),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: sessionsAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (error, stackTrace) => const SizedBox.shrink(),
                          data: (sessions) => DropdownButtonFormField<String?>(
                            initialValue: _sessionFilter,
                            decoration: const InputDecoration(
                              labelText: 'Session (all)',
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All sessions'),
                              ),
                              for (final session in sessions)
                                DropdownMenuItem<String?>(
                                  value: session.sessionId,
                                  child: Text(session.name),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _sessionFilter = value),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: classesAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (error, stackTrace) => const SizedBox.shrink(),
                          data: (classes) => DropdownButtonFormField<String?>(
                            initialValue: _classFilter,
                            decoration: const InputDecoration(
                              labelText: 'Class (all)',
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All classes'),
                              ),
                              for (final schoolClass in classes)
                                DropdownMenuItem<String?>(
                                  value: schoolClass.classId,
                                  child: Text(schoolClass.name),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _classFilter = value),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: batchesAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (error, stackTrace) => const SizedBox.shrink(),
                          data: (batches) => DropdownButtonFormField<String?>(
                            initialValue: _batchFilter,
                            decoration: const InputDecoration(
                              labelText: 'Batch (all)',
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All batches'),
                              ),
                              for (final batch in batches)
                                DropdownMenuItem<String?>(
                                  value: batch.batchId,
                                  child: Text(batch.name),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _batchFilter = value),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: subjectsAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (error, stackTrace) => const SizedBox.shrink(),
                          data: (subjects) => DropdownButtonFormField<String?>(
                            initialValue: _subjectFilter,
                            decoration: const InputDecoration(
                              labelText: 'Subject (all)',
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All subjects'),
                              ),
                              for (final subject in subjects)
                                DropdownMenuItem<String?>(
                                  value: subject.subjectId,
                                  child: Text(subject.name),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _subjectFilter = value),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SegmentedButton<_StatusFilter>(
                    segments: const [
                      ButtonSegment(
                        value: _StatusFilter.all,
                        label: Text('All'),
                      ),
                      ButtonSegment(
                        value: _StatusFilter.draft,
                        label: Text('Draft'),
                      ),
                      ButtonSegment(
                        value: _StatusFilter.published,
                        label: Text('Published'),
                      ),
                      ButtonSegment(
                        value: _StatusFilter.closed,
                        label: Text('Closed'),
                      ),
                    ],
                    selected: {_statusFilter},
                    onSelectionChanged: (selection) =>
                        setState(() => _statusFilter = selection.first),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: workAsync.when(
                loading: () => const LoadingView(message: 'Loading...'),
                error: (error, stackTrace) => ErrorView(
                  message: 'Unable to load homework. Please try again.\n$error',
                ),
                data: (items) {
                  final filtered = items.where(_matches).toList();
                  if (filtered.isEmpty) {
                    return const EmptyView(
                      message: 'No homework or assignments available.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final work = filtered[index];
                      return _WorkTile(
                        work: work,
                        basePath: widget.basePath,
                        summary: work.status == AcademicWorkStatus.draft
                            ? null
                            : WorkCompletionSummary.of(
                                completionsByWork[work.workId] ?? const [],
                                studentCount:
                                    studentCountByBatch[work.batchId] ?? 0,
                              ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkTile extends StatelessWidget {
  const _WorkTile({
    required this.work,
    required this.basePath,
    required this.summary,
  });

  final AcademicWork work;
  final String basePath;

  /// `null` for a draft, which nobody can be marked on yet.
  final WorkCompletionSummary? summary;

  @override
  Widget build(BuildContext context) {
    final overdue = work.isOverdue(DateTime.now());
    return Card(
      child: ListTile(
        title: Text('${work.title} (${work.subject})'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${work.type.label} - Due ${dateKey(work.dueDate)}'
              '${overdue ? ' - Overdue' : ''}',
            ),
            if (summary != null) ...[
              const SizedBox(height: AppSpacing.xs),
              WorkCompletionSummaryRow(summary: summary!),
            ],
          ],
        ),
        trailing: Chip(label: Text(work.status.label)),
        onTap: () => context.push('$basePath/${work.workId}'),
      ),
    );
  }
}
