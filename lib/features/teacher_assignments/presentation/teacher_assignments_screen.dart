import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../academics/data/academic_session.dart';
import '../../academics/data/academics_repositories.dart';
import '../../academics/data/school_class.dart';
import '../../academics/data/subject.dart';
import '../../batches/data/batch.dart';
import '../../batches/data/batch_repository.dart';
import '../../teacher/data/teacher_profile.dart';
import '../../teacher/data/teacher_repository.dart';
import '../application/teacher_assignment_controller.dart';
import '../data/teacher_assignment.dart';
import '../data/teacher_assignment_repository.dart';
import 'teacher_assignment_form_dialog.dart';

enum _StatusFilter { all, active, inactive }

/// Admin's teacher-assignment management area (Set 22 section 8): search
/// plus session/class/batch/subject/teacher/status filters over
/// `allTeacherAssignmentsProvider`, all applied client-side on that one
/// stream - the same "one stream, filter in the UI" approach as
/// `BatchListScreen`/`TeacherListScreen` at this project's scale.
class TeacherAssignmentsScreen extends ConsumerStatefulWidget {
  const TeacherAssignmentsScreen({super.key});

  @override
  ConsumerState<TeacherAssignmentsScreen> createState() =>
      _TeacherAssignmentsScreenState();
}

class _TeacherAssignmentsScreenState
    extends ConsumerState<TeacherAssignmentsScreen> {
  final _searchController = TextEditingController();
  String? _teacherFilter;
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

  bool _matchesSearch(
    TeacherAssignment assignment, {
    required List<TeacherProfile> teachers,
    required List<SchoolClass> classes,
    required List<Batch> batches,
    required List<Subject> subjects,
  }) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    final teacherName =
        teachers.where((t) => t.uid == assignment.teacherId).firstOrNull?.name ??
        '';
    final className =
        classes.where((c) => c.classId == assignment.classId).firstOrNull?.name ??
        '';
    final batchName =
        batches.where((b) => b.batchId == assignment.batchId).firstOrNull?.name ??
        '';
    final subjectName =
        subjects
            .where((s) => s.subjectId == assignment.subjectId)
            .firstOrNull
            ?.name ??
        '';
    return teacherName.toLowerCase().contains(query) ||
        className.toLowerCase().contains(query) ||
        batchName.toLowerCase().contains(query) ||
        subjectName.toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final assignmentsAsync = ref.watch(allTeacherAssignmentsProvider);
    final teachersAsync = ref.watch(allTeachersProvider);
    final sessionsAsync = ref.watch(allAcademicSessionsProvider);
    final classesAsync = ref.watch(allSchoolClassesProvider);
    final batchesAsync = ref.watch(allBatchesProvider);
    final subjectsAsync = ref.watch(allSubjectsProvider);

    final teachers = teachersAsync.valueOrNull ?? const <TeacherProfile>[];
    final sessions = sessionsAsync.valueOrNull ?? const <AcademicSession>[];
    final classes = classesAsync.valueOrNull ?? const <SchoolClass>[];
    final batches = batchesAsync.valueOrNull ?? const <Batch>[];
    final subjects = subjectsAsync.valueOrNull ?? const <Subject>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Teacher assignments')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTeacherAssignmentFormDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add assignment'),
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
                    label: 'Search by teacher, class, batch or subject',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: _teacherFilter,
                          decoration: const InputDecoration(
                            labelText: 'Teacher (all)',
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('All teachers'),
                            ),
                            for (final teacher in teachers)
                              DropdownMenuItem<String?>(
                                value: teacher.uid,
                                child: Text(teacher.name),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _teacherFilter = value),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
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
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
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
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
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
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String?>(
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
                    onChanged: (value) => setState(() => _subjectFilter = value),
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
              child: assignmentsAsync.when(
                loading: () =>
                    const LoadingView(message: 'Loading assignments...'),
                error: (error, stackTrace) =>
                    ErrorView(message: 'Could not load assignments.\n$error'),
                data: (assignments) {
                  final filtered = assignmentsMatching(
                    assignments,
                    teacherId: _teacherFilter,
                    academicSessionId: _sessionFilter,
                    classId: _classFilter,
                    batchId: _batchFilter,
                    subjectId: _subjectFilter,
                    active: switch (_statusFilter) {
                      _StatusFilter.all => null,
                      _StatusFilter.active => true,
                      _StatusFilter.inactive => false,
                    },
                  ).where(
                    (a) => _matchesSearch(
                      a,
                      teachers: teachers,
                      classes: classes,
                      batches: batches,
                      subjects: subjects,
                    ),
                  ).toList();

                  if (filtered.isEmpty) {
                    return const EmptyView(
                      message: 'No assignments match these filters.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) => _AssignmentTile(
                      assignment: filtered[index],
                      teachers: teachers,
                      sessions: sessions,
                      classes: classes,
                      batches: batches,
                      subjects: subjects,
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

class _AssignmentTile extends ConsumerWidget {
  const _AssignmentTile({
    required this.assignment,
    required this.teachers,
    required this.sessions,
    required this.classes,
    required this.batches,
    required this.subjects,
  });

  final TeacherAssignment assignment;
  final List<TeacherProfile> teachers;
  final List<AcademicSession> sessions;
  final List<SchoolClass> classes;
  final List<Batch> batches;
  final List<Subject> subjects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacherName =
        teachers.where((t) => t.uid == assignment.teacherId).firstOrNull?.name ??
        'Unknown teacher';
    final sessionName = sessions
        .where((s) => s.sessionId == assignment.academicSessionId)
        .firstOrNull
        ?.name;
    final className = classes
        .where((c) => c.classId == assignment.classId)
        .firstOrNull
        ?.name;
    final batchName = batches
        .where((b) => b.batchId == assignment.batchId)
        .firstOrNull
        ?.name;
    final subjectName = subjects
        .where((s) => s.subjectId == assignment.subjectId)
        .firstOrNull
        ?.name;

    return Card(
      child: ListTile(
        title: Text('$teacherName - ${subjectName ?? 'Unknown subject'}'),
        subtitle: Text(
          '${className ?? 'Unknown class'} - ${batchName ?? 'Unknown batch'}\n'
          '${sessionName ?? 'Unknown session'}'
          '${assignment.active ? '' : '   (inactive)'}',
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<bool>(
          onSelected: (active) async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              await ref
                  .read(teacherAssignmentControllerProvider)
                  .setActive(assignment, active);
            } on TeacherAssignmentFailure catch (failure) {
              messenger.showSnackBar(SnackBar(content: Text(failure.message)));
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: !assignment.active,
              child: Text(assignment.active ? 'Deactivate' : 'Activate'),
            ),
          ],
        ),
      ),
    );
  }
}
