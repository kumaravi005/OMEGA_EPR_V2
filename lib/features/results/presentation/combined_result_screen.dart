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
import '../../tests/data/test_definition.dart';
import '../../tests/data/test_repository.dart';
import '../../tests/data/test_result.dart';
import '../data/result_calculator.dart';

/// A combined multi-subject result: Session -> Class -> (matching active
/// batches), then admin checks which subjects to combine and, for each,
/// which of that subject's tests to use - a Set 14 test always belongs
/// to one subject, so combining subjects always means picking one real
/// test per subject, never a fabricated shared test id (Set 15 spec).
class CombinedResultScreen extends ConsumerStatefulWidget {
  const CombinedResultScreen({super.key});

  @override
  ConsumerState<CombinedResultScreen> createState() =>
      _CombinedResultScreenState();
}

class _CombinedResultScreenState extends ConsumerState<CombinedResultScreen> {
  String? _sessionId;
  String? _classId;
  String? _batchId;
  final Set<String> _selectedSubjectIds = {};
  final Map<String, String?> _testForSubject = {};

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(allAcademicSessionsProvider);
    final classesAsync = ref.watch(activeSchoolClassesProvider);
    final batchesAsync = ref.watch(activeBatchesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Combined result')),
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
                        _selectedSubjectIds.clear();
                        _testForSubject.clear();
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
                        _selectedSubjectIds.clear();
                        _testForSubject.clear();
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
                          _selectedSubjectIds.clear();
                          _testForSubject.clear();
                        }),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _batchId == null
                  ? const EmptyView(
                      message: 'Select a session, class and batch to continue.',
                    )
                  : _SubjectPickerAndResult(
                      batchId: _batchId!,
                      selectedSubjectIds: _selectedSubjectIds,
                      testForSubject: _testForSubject,
                      onSubjectToggled: (subjectId, selected) => setState(() {
                        if (selected) {
                          _selectedSubjectIds.add(subjectId);
                        } else {
                          _selectedSubjectIds.remove(subjectId);
                          _testForSubject.remove(subjectId);
                        }
                      }),
                      onTestChosen: (subjectId, testId) =>
                          setState(() => _testForSubject[subjectId] = testId),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectPickerAndResult extends ConsumerWidget {
  const _SubjectPickerAndResult({
    required this.batchId,
    required this.selectedSubjectIds,
    required this.testForSubject,
    required this.onSubjectToggled,
    required this.onTestChosen,
  });

  final String batchId;
  final Set<String> selectedSubjectIds;
  final Map<String, String?> testForSubject;
  final void Function(String subjectId, bool selected) onSubjectToggled;
  final void Function(String subjectId, String? testId) onTestChosen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testsAsync = ref.watch(batchTestsProvider(batchId));

    return testsAsync.when(
      loading: () => const LoadingView(),
      error: (error, stackTrace) =>
          ErrorView(message: 'Could not load tests.\n$error'),
      data: (tests) {
        if (tests.isEmpty) {
          return const EmptyView(message: 'No tests for this batch yet.');
        }
        final subjectNames = <String, String>{};
        for (final test in tests) {
          subjectNames[test.subjectId] = test.subject;
        }
        final subjectIds = subjectNames.keys.toList()
          ..sort((a, b) => subjectNames[a]!.compareTo(subjectNames[b]!));

        // Auto-pick the only (or most recent) test for a newly-selected
        // subject, so admin isn't forced to open a dropdown when there's
        // one obvious choice.
        for (final subjectId in selectedSubjectIds) {
          if (testForSubject[subjectId] != null) continue;
          final subjectTests = tests
              .where((t) => t.subjectId == subjectId)
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));
          if (subjectTests.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => onTestChosen(subjectId, subjectTests.first.testId),
            );
          }
        }

        final selectedTests = [
          for (final subjectId in selectedSubjectIds)
            if (testForSubject[subjectId] != null)
              tests.firstWhere((t) => t.testId == testForSubject[subjectId]),
        ]..sort((a, b) => a.subject.compareTo(b.subject));

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text('Subjects', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final subjectId in subjectIds)
                  FilterChip(
                    label: Text(subjectNames[subjectId]!),
                    selected: selectedSubjectIds.contains(subjectId),
                    onSelected: (selected) =>
                        onSubjectToggled(subjectId, selected),
                  ),
              ],
            ),
            for (final subjectId in selectedSubjectIds)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: DropdownButtonFormField<String?>(
                  initialValue: testForSubject[subjectId],
                  decoration: InputDecoration(
                    labelText: '${subjectNames[subjectId]} test',
                  ),
                  items: [
                    for (final test in tests.where(
                      (t) => t.subjectId == subjectId,
                    ))
                      DropdownMenuItem<String?>(
                        value: test.testId,
                        child: Text('${test.title} - ${dateKey(test.date)}'),
                      ),
                  ],
                  onChanged: (testId) => onTestChosen(subjectId, testId),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            if (selectedTests.isEmpty)
              const EmptyView(
                message: 'Select at least one subject to see a combined result.',
              )
            else
              _CombinedResultTable(batchId: batchId, tests: selectedTests),
          ],
        );
      },
    );
  }
}

class _CombinedResultTable extends ConsumerWidget {
  const _CombinedResultTable({required this.batchId, required this.tests});

  final String batchId;
  final List<TestDefinition> tests;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(allStudentsProvider);
    final resultsAsync = ref.watch(allTestResultsProvider);

    if (studentsAsync.isLoading || resultsAsync.isLoading) {
      return const LoadingView();
    }
    final allStudents = studentsAsync.valueOrNull ?? const <StudentProfile>[];
    final testIds = tests.map((t) => t.testId).toSet();
    final allResults = (resultsAsync.valueOrNull ?? const <TestResult>[])
        .where((r) => testIds.contains(r.testId))
        .toList();

    final activeInBatch = allStudents
        .where((s) => s.batchId == batchId && s.active)
        .toList();
    final markedUids = allResults.map((r) => r.studentUid).toSet();
    final historicalExtras = allStudents.where(
      (s) => markedUids.contains(s.uid) && !activeInBatch.any((a) => a.uid == s.uid),
    );
    final students = [...activeInBatch, ...historicalExtras];

    if (students.isEmpty) {
      return const EmptyView(message: 'No students in this batch.');
    }

    final rows = computeCombinedResults(
      tests: tests,
      students: students,
      allResults: allResults,
    )..sort((a, b) {
      if (a.rank == null && b.rank == null) {
        return a.student.name.compareTo(b.student.name);
      }
      if (a.rank == null) return 1;
      if (b.rank == null) return -1;
      return a.rank!.compareTo(b.rank!);
    });

    final totalMaximum = tests.fold<double>(0, (sum, t) => sum + t.totalMarks);
    final completed = rows.where((r) => r.status == ResultStatus.complete).length;
    final absent = rows.where((r) => r.status == ResultStatus.absent).length;
    final incomplete = rows.where((r) => r.status == ResultStatus.incomplete).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Combined maximum: ${totalMaximum.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              const DataColumn(label: Text('Rank')),
              const DataColumn(label: Text('Student')),
              for (final test in tests) DataColumn(label: Text(test.subject)),
              const DataColumn(label: Text('Total')),
              const DataColumn(label: Text('Max')),
              const DataColumn(label: Text('%')),
              const DataColumn(label: Text('Status')),
            ],
            rows: [
              for (final row in rows)
                DataRow(
                  cells: [
                    DataCell(Text(row.rank == null ? '-' : '${row.rank}')),
                    DataCell(Text(row.student.name)),
                    for (final cell in row.cells)
                      DataCell(
                        Text(
                          switch (cell.status) {
                            CellStatus.present =>
                              cell.obtainedMarks!.toStringAsFixed(1),
                            CellStatus.absent => 'Absent',
                            CellStatus.missing => '-',
                          },
                        ),
                      ),
                    DataCell(
                      Text(row.totalObtained?.toStringAsFixed(1) ?? '-'),
                    ),
                    DataCell(
                      Text(row.totalMaximum?.toStringAsFixed(0) ?? '-'),
                    ),
                    DataCell(
                      Text(
                        row.percentage == null
                            ? '-'
                            : '${row.percentage!.toStringAsFixed(1)}%',
                      ),
                    ),
                    DataCell(Text(row.status.label)),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
