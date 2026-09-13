import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../academics/data/academic_session.dart';
import '../../academics/data/academics_repositories.dart';
import '../../academics/data/school_class.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/data/user_account.dart';
import '../../batches/data/batch.dart';
import '../../batches/data/batch_repository.dart';
import '../../student/data/student_profile.dart';
import '../../student/data/student_repository.dart';
import '../../teacher_assignments/data/teacher_assignment.dart';
import '../../teacher_assignments/data/teacher_assignment_repository.dart';
import '../application/attendance_controller.dart';
import '../data/attendance_repository.dart';
import '../data/student_attendance_record.dart';

/// Marks one common attendance record per batch/date, covering every
/// student in the batch - never split by subject (Set 13, unchanged by
/// Set 23). Admin picks any session -> class -> (matching active
/// batches); a signed-in teacher instead picks directly from their own
/// active `TeacherAssignment` batch scopes (Set 23 sections 3-5) - there
/// is no free session/class picker for a teacher, and no batch outside
/// their assignments is ever offered. Attendance itself has no subject
/// field (Set 13's own design, preserved - see
/// `TeacherAssignment`'s doc comment on why Set 23 does not invent one),
/// so a teacher's selection only needs to match session+batch, not
/// subject.
class MarkStudentAttendanceScreen extends ConsumerStatefulWidget {
  const MarkStudentAttendanceScreen({super.key});

  @override
  ConsumerState<MarkStudentAttendanceScreen> createState() =>
      _MarkStudentAttendanceScreenState();
}

class _MarkStudentAttendanceScreenState
    extends ConsumerState<MarkStudentAttendanceScreen> {
  String? _sessionId;
  String? _classId;
  String? _batchId;
  DateTime _date = DateTime.now();
  final Map<String, AttendanceStatus> _statuses = {};
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _prefilledFor;
  bool _defaultedSession = false;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  /// Seeds [_statuses] once per session/class/batch/date combination -
  /// defaults every currently-listed student to Present (admin still has
  /// to explicitly save, so nobody is silently marked present without
  /// review), or their existing status if this batch/date was already
  /// marked.
  void _prefillIfNeeded(
    String batchId,
    List<String> studentUids,
    StudentAttendanceRecord? existing,
  ) {
    final key = '${batchId}_${dateKey(_date)}';
    if (_prefilledFor == key) return;
    _prefilledFor = key;
    _statuses.clear();
    for (final uid in studentUids) {
      _statuses[uid] = existing?.records[uid] ?? AttendanceStatus.present;
    }
  }

  Future<void> _submit(
    String batchId,
    String academicSessionId,
    String classId,
  ) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(attendanceControllerProvider)
          .markStudentAttendance(
            batchId: batchId,
            academicSessionId: academicSessionId,
            classId: classId,
            date: _date,
            records: Map.of(_statuses),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Attendance saved.')));
    } on AttendanceFailure catch (failure) {
      setState(() => _errorMessage = failure.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(currentUserAccountProvider).valueOrNull;
    final isTeacher = account?.role == UserRole.teacher;

    if (isTeacher) {
      return _TeacherScopedBody(
        teacherId: account!.uid,
        sessionId: _sessionId,
        classId: _classId,
        batchId: _batchId,
        date: _date,
        isSubmitting: _isSubmitting,
        errorMessage: _errorMessage,
        statuses: _statuses,
        onScopeChanged: (assignment) => setState(() {
          _sessionId = assignment?.academicSessionId;
          _classId = assignment?.classId;
          _batchId = assignment?.batchId;
        }),
        onPickDate: _pickDate,
        onStatusChanged: (uid, status) =>
            setState(() => _statuses[uid] = status),
        onPrefill: _prefillIfNeeded,
        onSubmit: _submit,
      );
    }

    final sessionsAsync = ref.watch(allAcademicSessionsProvider);
    final classesAsync = ref.watch(activeSchoolClassesProvider);
    final batchesAsync = ref.watch(activeBatchesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Student attendance')),
      body: SafeArea(
        child: sessionsAsync.when(
          loading: () => const LoadingView(),
          error: (error, stackTrace) =>
              ErrorView(message: 'Could not load sessions.\n$error'),
          data: (sessions) {
            if (sessions.isEmpty) {
              return const EmptyView(
                message: 'No academic sessions yet - add one in '
                    'Configuration first.',
              );
            }
            if (!_defaultedSession) {
              _defaultedSession = true;
              _sessionId = sessions.where((s) => s.isActive).firstOrNull
                  ?.sessionId ??
                  sessions.first.sessionId;
            }

            return classesAsync.when(
              loading: () => const LoadingView(),
              error: (error, stackTrace) =>
                  ErrorView(message: 'Could not load classes.\n$error'),
              data: (classes) => batchesAsync.when(
                loading: () => const LoadingView(),
                error: (error, stackTrace) =>
                    ErrorView(message: 'Could not load batches.\n$error'),
                data: (batches) {
                  final matchingBatches = batchesForSessionAndClass(
                    batches,
                    academicSessionId: _sessionId,
                    classId: _classId,
                  );
                  if (!matchingBatches.any((b) => b.batchId == _batchId)) {
                    _batchId = matchingBatches.firstOrNull?.batchId;
                  }

                  return _Body(
                    sessions: sessions,
                    classes: classes,
                    matchingBatches: matchingBatches,
                    sessionId: _sessionId,
                    classId: _classId,
                    batchId: _batchId,
                    date: _date,
                    isSubmitting: _isSubmitting,
                    errorMessage: _errorMessage,
                    statuses: _statuses,
                    onSessionChanged: (value) => setState(() {
                      _sessionId = value;
                      _classId = null;
                      _batchId = null;
                    }),
                    onClassChanged: (value) => setState(() {
                      _classId = value;
                      _batchId = null;
                    }),
                    onBatchChanged: (value) => setState(() => _batchId = value),
                    onPickDate: _pickDate,
                    onStatusChanged: (uid, status) =>
                        setState(() => _statuses[uid] = status),
                    onPrefill: _prefillIfNeeded,
                    onSubmit: _submit,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A signed-in teacher's version of the same screen: instead of Session
/// -> Class -> Batch dropdowns, ONE dropdown built from
/// `ownTeacherAssignmentsProvider` (Set 22's rule-constrained self-read),
/// deduplicated by batch (`distinctActiveBatchScopes` - Set 23 section 5,
/// since a teacher may hold more than one subject-assignment to the same
/// batch and attendance itself has no subject). Everything below the
/// picker - date, student list, save - is the identical `_Body`
/// machinery the admin path uses, so there is exactly one attendance UI,
/// not two.
class _TeacherScopedBody extends ConsumerWidget {
  const _TeacherScopedBody({
    required this.teacherId,
    required this.sessionId,
    required this.classId,
    required this.batchId,
    required this.date,
    required this.isSubmitting,
    required this.errorMessage,
    required this.statuses,
    required this.onScopeChanged,
    required this.onPickDate,
    required this.onStatusChanged,
    required this.onPrefill,
    required this.onSubmit,
  });

  final String teacherId;
  final String? sessionId;
  final String? classId;
  final String? batchId;
  final DateTime date;
  final bool isSubmitting;
  final String? errorMessage;
  final Map<String, AttendanceStatus> statuses;
  final ValueChanged<TeacherAssignment?> onScopeChanged;
  final VoidCallback onPickDate;
  final void Function(String uid, AttendanceStatus status) onStatusChanged;
  final void Function(
    String batchId,
    List<String> studentUids,
    StudentAttendanceRecord? existing,
  )
  onPrefill;
  final Future<void> Function(
    String batchId,
    String academicSessionId,
    String classId,
  )
  onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(ownTeacherAssignmentsProvider(teacherId));
    final sessionsAsync = ref.watch(allAcademicSessionsProvider);
    final classesAsync = ref.watch(allSchoolClassesProvider);
    final batchesAsync = ref.watch(allBatchesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mark attendance')),
      body: SafeArea(
        child: assignmentsAsync.when(
          loading: () => const LoadingView(),
          error: (error, stackTrace) =>
              ErrorView(message: 'Could not load your assignments.\n$error'),
          data: (assignments) {
            final scopes = distinctActiveBatchScopes(assignments);
            if (scopes.isEmpty) {
              return const EmptyView(
                message: 'You have no active teaching assignments yet - '
                    'ask an admin to assign you to a class/batch.',
              );
            }

            final sessions = sessionsAsync.valueOrNull ?? const [];
            final classes = classesAsync.valueOrNull ?? const [];
            final batches = batchesAsync.valueOrNull ?? const [];
            final selected = scopes
                .where(
                  (a) => a.academicSessionId == sessionId && a.batchId == batchId,
                )
                .firstOrNull;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selected?.assignmentId,
                          decoration: const InputDecoration(
                            labelText: 'My class / batch',
                          ),
                          items: [
                            for (final scope in scopes)
                              DropdownMenuItem(
                                value: scope.assignmentId,
                                child: Text(
                                  _scopeLabel(scope, sessions, classes, batches),
                                ),
                              ),
                          ],
                          onChanged: isSubmitting
                              ? null
                              : (value) => onScopeChanged(
                                  scopes
                                      .where((s) => s.assignmentId == value)
                                      .firstOrNull,
                                ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      TextButton.icon(
                        onPressed: isSubmitting ? null : onPickDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(dateKey(date)),
                      ),
                    ],
                  ),
                ),
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Text(
                      errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Expanded(
                  child: batchId == null
                      ? const EmptyView(
                          message: 'Select a class/batch to continue.',
                        )
                      : _StudentAttendanceList(
                          batchId: batchId!,
                          date: date,
                          statuses: statuses,
                          isSubmitting: isSubmitting,
                          onStatusChanged: onStatusChanged,
                          onPrefill: onPrefill,
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: AppButton(
                    label: 'Save attendance',
                    isLoading: isSubmitting,
                    onPressed: batchId == null || sessionId == null || classId == null
                        ? null
                        : () => onSubmit(batchId!, sessionId!, classId!),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _scopeLabel(
    TeacherAssignment scope,
    List<AcademicSession> sessions,
    List<SchoolClass> classes,
    List<Batch> batches,
  ) {
    final sessionName = sessions
        .where((s) => s.sessionId == scope.academicSessionId)
        .firstOrNull
        ?.name;
    final className = classes
        .where((c) => c.classId == scope.classId)
        .firstOrNull
        ?.name;
    final batchName = batches
        .where((b) => b.batchId == scope.batchId)
        .firstOrNull
        ?.name;
    return '${className ?? 'Unknown class'} - ${batchName ?? 'Unknown batch'}'
        '${sessionName != null ? ' ($sessionName)' : ''}';
  }
}

/// The student roster + present/absent toggles for one batch/date -
/// factored out so both the admin (`_Body`) and teacher
/// (`_TeacherScopedBody`) paths render the identical list without
/// duplicating the historical-student-preservation logic (Set 13 section
/// 6/22: a student who has since left the batch must still show up when
/// editing a past date that already recorded them).
class _StudentAttendanceList extends ConsumerWidget {
  const _StudentAttendanceList({
    required this.batchId,
    required this.date,
    required this.statuses,
    required this.isSubmitting,
    required this.onStatusChanged,
    required this.onPrefill,
  });

  final String batchId;
  final DateTime date;
  final Map<String, AttendanceStatus> statuses;
  final bool isSubmitting;
  final void Function(String uid, AttendanceStatus status) onStatusChanged;
  final void Function(
    String batchId,
    List<String> studentUids,
    StudentAttendanceRecord? existing,
  )
  onPrefill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(allStudentsProvider);
    final existingAsync = ref.watch(batchAttendanceProvider(batchId));
    return studentsAsync.when(
      loading: () => const LoadingView(),
      error: (error, stackTrace) =>
          ErrorView(message: 'Could not load students.\n$error'),
      data: (allStudents) {
        final existing = existingAsync.valueOrNull
            ?.where((r) => r.dateKey == dateKey(date))
            .firstOrNull;

        final activeInBatch = allStudents
            .where((s) => s.batchId == batchId && s.active)
            .toList();
        final historicalExtras = existing == null
            ? <StudentProfile>[]
            : allStudents
                  .where(
                    (s) =>
                        existing.records.containsKey(s.uid) &&
                        !activeInBatch.any((a) => a.uid == s.uid),
                  )
                  .toList();
        final students = [...activeInBatch, ...historicalExtras];

        if (students.isEmpty) {
          return const EmptyView(message: 'No students in this batch.');
        }

        onPrefill(batchId, students.map((s) => s.uid).toList(), existing);

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: students.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
          itemBuilder: (context, index) {
            final student = students[index];
            final status = statuses[student.uid] ?? AttendanceStatus.present;
            return Card(
              child: ListTile(
                title: Text('${student.name} (${student.accountId})'),
                subtitle: student.active
                    ? null
                    : const Text(
                        'No longer in this batch',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                trailing: ToggleButtons(
                  isSelected: [
                    status == AttendanceStatus.present,
                    status == AttendanceStatus.absent,
                  ],
                  onPressed: isSubmitting
                      ? null
                      : (i) => onStatusChanged(
                          student.uid,
                          i == 0
                              ? AttendanceStatus.present
                              : AttendanceStatus.absent,
                        ),
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('P'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('A'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.sessions,
    required this.classes,
    required this.matchingBatches,
    required this.sessionId,
    required this.classId,
    required this.batchId,
    required this.date,
    required this.isSubmitting,
    required this.errorMessage,
    required this.statuses,
    required this.onSessionChanged,
    required this.onClassChanged,
    required this.onBatchChanged,
    required this.onPickDate,
    required this.onStatusChanged,
    required this.onPrefill,
    required this.onSubmit,
  });

  final List<AcademicSession> sessions;
  final List<SchoolClass> classes;
  final List<Batch> matchingBatches;
  final String? sessionId;
  final String? classId;
  final String? batchId;
  final DateTime date;
  final bool isSubmitting;
  final String? errorMessage;
  final Map<String, AttendanceStatus> statuses;
  final ValueChanged<String?> onSessionChanged;
  final ValueChanged<String?> onClassChanged;
  final ValueChanged<String?> onBatchChanged;
  final VoidCallback onPickDate;
  final void Function(String uid, AttendanceStatus status) onStatusChanged;
  final void Function(
    String batchId,
    List<String> studentUids,
    StudentAttendanceRecord? existing,
  )
  onPrefill;
  final Future<void> Function(
    String batchId,
    String academicSessionId,
    String classId,
  )
  onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: sessionId,
                      decoration: const InputDecoration(
                        labelText: 'Academic session',
                      ),
                      items: [
                        for (final session in sessions)
                          DropdownMenuItem(
                            value: session.sessionId,
                            child: Text(session.name),
                          ),
                      ],
                      onChanged: isSubmitting ? null : onSessionChanged,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  TextButton.icon(
                    onPressed: isSubmitting ? null : onPickDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(dateKey(date)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                key: ValueKey('class-$sessionId'),
                initialValue: classId,
                decoration: const InputDecoration(labelText: 'Class'),
                items: [
                  for (final schoolClass in classes)
                    DropdownMenuItem(
                      value: schoolClass.classId,
                      child: Text(schoolClass.name),
                    ),
                ],
                onChanged: isSubmitting ? null : onClassChanged,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (sessionId == null || classId == null)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Select a session and class to see batches.'),
                )
              else if (matchingBatches.isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'No active batches for this session/class.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  key: ValueKey('batch-$sessionId-$classId'),
                  initialValue: batchId,
                  decoration: const InputDecoration(labelText: 'Batch'),
                  items: [
                    for (final batch in matchingBatches)
                      DropdownMenuItem(
                        value: batch.batchId,
                        child: Text(batch.name),
                      ),
                  ],
                  onChanged: isSubmitting ? null : onBatchChanged,
                ),
            ],
          ),
        ),
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Expanded(
          child: batchId == null
              ? const EmptyView(
                  message: 'Select a session, class and batch to continue.',
                )
              : _StudentAttendanceList(
                  batchId: batchId!,
                  date: date,
                  statuses: statuses,
                  isSubmitting: isSubmitting,
                  onStatusChanged: onStatusChanged,
                  onPrefill: onPrefill,
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: AppButton(
            label: 'Save attendance',
            isLoading: isSubmitting,
            onPressed: batchId == null || sessionId == null || classId == null
                ? null
                : () => onSubmit(batchId!, sessionId!, classId!),
          ),
        ),
      ],
    );
  }
}
