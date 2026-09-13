import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../academics/data/academics_repositories.dart';
import '../../batches/data/batch_repository.dart';
import '../../student/data/student_profile.dart';
import '../../student/data/student_repository.dart';
import '../../tests/data/test_repository.dart';
import '../data/result_calculator.dart';

/// A single test's result - Session -> Class -> (matching active
/// batches) -> Subject (narrows the test list) -> Test, then a ranked
/// table. Serves both the hub's "Subject-wise Result" and "Test Result"
/// entries: a Set 14 test always belongs to exactly one subject, so
/// "pick a subject, see its test(s)" and "pick a test directly" are the
/// same underlying view - one screen, not a duplicate (Set 15 spec:
/// "do not create unnecessary duplicate screens").
class TestResultScreen extends ConsumerStatefulWidget {
  const TestResultScreen({super.key});

  @override
  ConsumerState<TestResultScreen> createState() => _TestResultScreenState();
}

class _TestResultScreenState extends ConsumerState<TestResultScreen> {
  String? _sessionId;
  String? _classId;
  String? _batchId;
  String? _subjectId;
  String? _testId;

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(allAcademicSessionsProvider);
    final classesAsync = ref.watch(activeSchoolClassesProvider);
    final batchesAsync = ref.watch(activeBatchesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Test / Subject result')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  sessionsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (error, stackTrace) => const SizedBox.shrink(),
                    data: (sessions) => DropdownButtonFormField<String?>(
                      initialValue: _sessionId,
                      decoration: const InputDecoration(
                        labelText: 'Academic session',
                      ),
                      items: [
                        for (final session in sessions)
                          DropdownMenuItem<String?>(
                            value: session.sessionId,
                            child: Text(session.name),
                          ),
                      ],
                      onChanged: (value) => setState(() {
                        _sessionId = value;
                        _classId = null;
                        _batchId = null;
                        _subjectId = null;
                        _testId = null;
                      }),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  classesAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (error, stackTrace) => const SizedBox.shrink(),
                    data: (classes) => DropdownButtonFormField<String?>(
                      initialValue: _classId,
                      decoration: const InputDecoration(labelText: 'Class'),
                      items: [
                        for (final schoolClass in classes)
                          DropdownMenuItem<String?>(
                            value: schoolClass.classId,
                            child: Text(schoolClass.name),
                          ),
                      ],
                      onChanged: (value) => setState(() {
                        _classId = value;
                        _batchId = null;
                        _subjectId = null;
                        _testId = null;
                      }),
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
                        return const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Select a session and class to see batches.',
                          ),
                        );
                      }
                      if (matching.isEmpty) {
                        return const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('No active batches for this session/class.'),
                        );
                      }
                      return DropdownButtonFormField<String?>(
                        key: ValueKey('batch-$_sessionId-$_classId'),
                        initialValue: matching.any((b) => b.batchId == _batchId)
                            ? _batchId
                            : null,
                        decoration: const InputDecoration(labelText: 'Batch'),
                        items: [
                          for (final batch in matching)
                            DropdownMenuItem<String?>(
                              value: batch.batchId,
                              child: Text(batch.name),
                            ),
                        ],
                        onChanged: (value) => setState(() {
                          _batchId = value;
                          _subjectId = null;
                          _testId = null;
                        }),
                      );
                    },
                  ),
                  if (_batchId != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Consumer(
                      builder: (context, ref, _) {
                        final testsAsync = ref.watch(
                          batchTestsProvider(_batchId!),
                        );
                        return testsAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (error, stackTrace) => const SizedBox.shrink(),
                          data: (tests) {
                            if (tests.isEmpty) {
                              return const Align(
                                alignment: Alignment.centerLeft,
                                child: Text('No tests for this batch yet.'),
                              );
                            }
                            final subjects = {
                              for (final t in tests) t.subjectId: t.subject,
                            };
                            final testsForSubject = _subjectId == null
                                ? tests
                                : tests
                                      .where((t) => t.subjectId == _subjectId)
                                      .toList();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                DropdownButtonFormField<String?>(
                                  initialValue: _subjectId,
                                  decoration: const InputDecoration(
                                    labelText: 'Subject (all)',
                                  ),
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('All subjects'),
                                    ),
                                    for (final entry in subjects.entries)
                                      DropdownMenuItem<String?>(
                                        value: entry.key,
                                        child: Text(entry.value),
                                      ),
                                  ],
                                  onChanged: (value) => setState(() {
                                    _subjectId = value;
                                    _testId = null;
                                  }),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                DropdownButtonFormField<String?>(
                                  key: ValueKey('test-$_subjectId'),
                                  initialValue:
                                      testsForSubject.any(
                                        (t) => t.testId == _testId,
                                      )
                                      ? _testId
                                      : null,
                                  decoration: const InputDecoration(
                                    labelText: 'Test',
                                  ),
                                  items: [
                                    for (final test in testsForSubject)
                                      DropdownMenuItem<String?>(
                                        value: test.testId,
                                        child: Text(
                                          '${test.title} (${test.subject}) - '
                                          '${dateKey(test.date)}',
                                        ),
                                      ),
                                  ],
                                  onChanged: (value) =>
                                      setState(() => _testId = value),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _testId == null
                  ? const EmptyView(message: 'Select a test to see its result.')
                  : _ResultBody(batchId: _batchId!, testId: _testId!),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultBody extends ConsumerWidget {
  const _ResultBody({required this.batchId, required this.testId});

  final String batchId;
  final String testId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testAsync = ref.watch(testByIdProvider(testId));
    final studentsAsync = ref.watch(allStudentsProvider);
    final resultsAsync = ref.watch(testResultsForTestProvider(testId));

    if (testAsync.isLoading || studentsAsync.isLoading) {
      return const LoadingView();
    }
    final test = testAsync.valueOrNull;
    if (test == null) return const ErrorView(message: 'Test not found.');
    final allStudents = studentsAsync.valueOrNull ?? const <StudentProfile>[];
    final results = resultsAsync.valueOrNull ?? const [];

    final activeInBatch = allStudents
        .where((s) => s.batchId == batchId && s.active)
        .toList();
    final markedUids = results.map((r) => r.studentUid).toSet();
    final historicalExtras = allStudents.where(
      (s) => markedUids.contains(s.uid) && !activeInBatch.any((a) => a.uid == s.uid),
    );
    final students = [...activeInBatch, ...historicalExtras];

    if (students.isEmpty) {
      return const EmptyView(message: 'No students in this batch.');
    }

    final rows = computeSubjectResults(
      test: test,
      students: students,
      results: results,
    )..sort((a, b) {
      if (a.rank == null && b.rank == null) {
        return a.student.name.compareTo(b.student.name);
      }
      if (a.rank == null) return 1;
      if (b.rank == null) return -1;
      return a.rank!.compareTo(b.rank!);
    });

    final completed = rows.where((r) => r.status == ResultStatus.complete).length;
    final absent = rows.where((r) => r.status == ResultStatus.absent).length;
    final incomplete = rows.where((r) => r.status == ResultStatus.incomplete).length;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${test.title} - ${test.subject}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('Out of ${test.totalMarks.toStringAsFixed(0)} marks'),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.md,
                children: [
                  Text('Students: ${students.length}'),
                  Text('Completed: $completed'),
                  Text('Absent: $absent'),
                  Text('Incomplete: $incomplete'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final row in rows) _ResultTile(row: row),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.row});

  final SubjectResultRow row;

  @override
  Widget build(BuildContext context) {
    final valueText = switch (row.status) {
      ResultStatus.complete =>
        '${row.cell.obtainedMarks!.toStringAsFixed(1)}/${row.totalMarks.toStringAsFixed(0)} '
            '(${row.percentage!.toStringAsFixed(1)}%)',
      ResultStatus.absent => 'Absent',
      ResultStatus.incomplete => 'Not entered',
    };

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text(row.rank == null ? '-' : '${row.rank}'),
        ),
        title: Text(row.student.name),
        subtitle: row.student.admissionNumber.isEmpty
            ? null
            : Text('Adm. no. ${row.student.admissionNumber}'),
        trailing: Text(
          valueText,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: row.status == ResultStatus.complete
                ? null
                : Theme.of(context).colorScheme.error,
          ),
        ),
      ),
    );
  }
}
