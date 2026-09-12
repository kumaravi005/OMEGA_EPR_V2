import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../academics/data/academics_repositories.dart';
import '../../academics/data/school_class.dart';
import '../../batches/data/batch.dart';
import '../../batches/data/batch_repository.dart';
import '../data/student_profile.dart';
import '../data/student_repository.dart';

enum _StatusFilter { all, active, inactive }

/// Admin's student list - search by name/admission number/account id,
/// filter by session/class/batch/status. All filtering happens
/// client-side on the one `allStudentsProvider` stream, matching
/// `BatchListScreen`'s established pattern at this project's scale
/// (~200 students).
class StudentListScreen extends ConsumerStatefulWidget {
  const StudentListScreen({super.key});

  @override
  ConsumerState<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends ConsumerState<StudentListScreen> {
  final _searchController = TextEditingController();
  String? _sessionFilter;
  String? _classFilter;
  String? _batchFilter;
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

  bool _matches(StudentProfile student) {
    final query = _searchController.text.trim().toLowerCase();
    final matchesQuery =
        query.isEmpty ||
        student.name.toLowerCase().contains(query) ||
        student.admissionNumber.toLowerCase().contains(query) ||
        student.accountId.toLowerCase().contains(query);
    final matchesSession =
        _sessionFilter == null || student.academicSessionId == _sessionFilter;
    final matchesClass = _classFilter == null || student.classId == _classFilter;
    final matchesBatch = _batchFilter == null || student.batchId == _batchFilter;
    final matchesStatus = switch (_statusFilter) {
      _StatusFilter.all => true,
      _StatusFilter.active => student.active,
      _StatusFilter.inactive => !student.active,
    };
    return matchesQuery &&
        matchesSession &&
        matchesClass &&
        matchesBatch &&
        matchesStatus;
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(allStudentsProvider);
    final sessionsAsync = ref.watch(allAcademicSessionsProvider);
    final classesAsync = ref.watch(allSchoolClassesProvider);
    final batchesAsync = ref.watch(allBatchesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Students')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.adminNewStudent),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('New admission'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  AppTextField(
                    controller: _searchController,
                    label: 'Search by name, admission no. or account ID',
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
                  batchesAsync.when(
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
              child: studentsAsync.when(
                loading: () => const LoadingView(message: 'Loading students...'),
                error: (error, stackTrace) =>
                    ErrorView(message: 'Could not load students.\n$error'),
                data: (students) {
                  final filtered = students.where(_matches).toList();
                  if (filtered.isEmpty) {
                    return const EmptyView(
                      message: 'No students match these filters.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) => _StudentTile(
                      student: filtered[index],
                      classes: classesAsync.valueOrNull ?? const [],
                      batches: batchesAsync.valueOrNull ?? const [],
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

class _StudentTile extends StatelessWidget {
  const _StudentTile({
    required this.student,
    required this.classes,
    required this.batches,
  });

  final StudentProfile student;
  final List<SchoolClass> classes;
  final List<Batch> batches;

  @override
  Widget build(BuildContext context) {
    final className = classes
        .where((c) => c.classId == student.classId)
        .firstOrNull
        ?.name ??
        student.className;
    final batchName = batches
        .where((b) => b.batchId == student.batchId)
        .firstOrNull
        ?.name;

    final subtitleParts = <String>[
      if (student.admissionNumber.isNotEmpty)
        'Adm. no. ${student.admissionNumber}',
      className,
      ?batchName,
      if (student.board.isNotEmpty) student.board,
      student.primaryMobile,
    ];

    return Card(
      child: ListTile(
        title: Text('${student.name} (${student.accountId})'),
        subtitle: Text(
          '${subtitleParts.join(' - ')}'
          '${student.active ? '' : '   (inactive)'}',
        ),
        isThreeLine: true,
        onTap: () => context.push('${AppRoutes.adminStudents}/${student.uid}'),
      ),
    );
  }
}
