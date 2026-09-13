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
import '../../teacher_assignments/data/teacher_assignment_repository.dart';
import '../data/test_definition.dart';
import '../data/test_repository.dart';
import 'create_test_dialog.dart';

enum _StatusFilter { all, active, inactive }

/// Admin/teacher test list: search by title, filter by session/class/
/// batch/subject/type, tap a test to open its details. Reached from both
/// `/admin/tests` and `/teacher/tests` (see lib/router.dart) - [basePath]
/// is whichever of those the caller came from, so tapping a test
/// navigates to the matching role's test-details route. Admin always sees
/// the "New test" action; a teacher sees it once they hold at least one
/// active `TeacherAssignment` (Set 22/23 - creating a test is no longer
/// admin-only, now that assignment-derived authorization exists).
class TestListScreen extends ConsumerStatefulWidget {
  const TestListScreen({super.key, required this.basePath});

  final String basePath;

  @override
  ConsumerState<TestListScreen> createState() => _TestListScreenState();
}

class _TestListScreenState extends ConsumerState<TestListScreen> {
  final _searchController = TextEditingController();
  String? _sessionFilter;
  String? _classFilter;
  String? _batchFilter;
  String? _subjectFilter;
  _StatusFilter _statusFilter = _StatusFilter.active;

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

  bool _matches(TestDefinition test) {
    final query = _searchController.text.trim().toLowerCase();
    final matchesQuery =
        query.isEmpty || test.title.toLowerCase().contains(query);
    final matchesSession =
        _sessionFilter == null || test.academicSessionId == _sessionFilter;
    final matchesClass = _classFilter == null || test.classId == _classFilter;
    final matchesBatch = _batchFilter == null || test.batchId == _batchFilter;
    final matchesSubject =
        _subjectFilter == null || test.subjectId == _subjectFilter;
    final matchesStatus = switch (_statusFilter) {
      _StatusFilter.all => true,
      _StatusFilter.active => test.active,
      _StatusFilter.inactive => !test.active,
    };
    return matchesQuery &&
        matchesSession &&
        matchesClass &&
        matchesBatch &&
        matchesSubject &&
        matchesStatus;
  }

  @override
  Widget build(BuildContext context) {
    final testsAsync = ref.watch(allTestsProvider);
    final sessionsAsync = ref.watch(allAcademicSessionsProvider);
    final classesAsync = ref.watch(allSchoolClassesProvider);
    final batchesAsync = ref.watch(allBatchesProvider);
    final subjectsAsync = ref.watch(allSubjectsProvider);
    final account = ref.watch(currentUserAccountProvider).valueOrNull;
    final isAdmin = account?.role == UserRole.admin;
    final isTeacher = account?.role == UserRole.teacher;
    final teacherHasActiveAssignment = isTeacher && account != null
        ? (ref.watch(ownTeacherAssignmentsProvider(account.uid)).valueOrNull ?? const [])
              .any((a) => a.active)
        : false;

    return Scaffold(
      appBar: AppBar(title: const Text('Tests')),
      floatingActionButton: isAdmin || teacherHasActiveAssignment
          ? FloatingActionButton.extended(
              onPressed: () => showCreateTestDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('New test'),
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
                    label: 'Search by test title',
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
                        value: _StatusFilter.active,
                        label: Text('Active'),
                      ),
                      ButtonSegment(
                        value: _StatusFilter.inactive,
                        label: Text('Inactive'),
                      ),
                      ButtonSegment(value: _StatusFilter.all, label: Text('All')),
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
              child: testsAsync.when(
                loading: () => const LoadingView(message: 'Loading tests...'),
                error: (error, stackTrace) =>
                    ErrorView(message: 'Could not load tests.\n$error'),
                data: (tests) {
                  final filtered = tests.where(_matches).toList();
                  if (filtered.isEmpty) {
                    return const EmptyView(
                      message: 'No tests match these filters.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) => _TestTile(
                      test: filtered[index],
                      basePath: widget.basePath,
                    ),
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

class _TestTile extends StatelessWidget {
  const _TestTile({required this.test, required this.basePath});

  final TestDefinition test;
  final String basePath;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('${test.title} (${test.subject})'),
        subtitle: Text(
          '${test.chapterTopic} - ${dateKey(test.date)} - '
          '${test.totalMarks.toStringAsFixed(0)} marks'
          '${test.active ? '' : '   (inactive)'}',
        ),
        trailing: Chip(
          label: Text(test.resultPublished ? 'Published' : 'Draft'),
        ),
        onTap: () => context.push('$basePath/${test.testId}'),
      ),
    );
  }
}
