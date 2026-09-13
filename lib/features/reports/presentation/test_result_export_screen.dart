import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/export/export_dataset.dart';
import '../../../core/export/export_format.dart';
import '../../../core/export/export_service.dart';
import '../../../core/export/report_branding.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/utils/error_formatting.dart';
import '../../../core/widgets/app_button.dart';
import '../../batches/data/batch_repository.dart';
import '../../report_templates/data/report_layout_template_repository.dart';
import '../../report_templates/presentation/widgets/report_layout_picker.dart';
import '../../results/data/result_calculator.dart';
import '../../student/data/student_profile.dart';
import '../../student/data/student_repository.dart';
import '../../tests/data/test_definition.dart';
import '../../tests/data/test_repository.dart';
import '../../tests/data/test_result.dart';
import 'widgets/format_and_orientation_picker.dart';

enum TestReportMode {
  specificTest('Specific test'),
  subjectWise('Subject-wise (multiple tests, one subject)'),
  multiSubject('Multi-subject combined');

  const TestReportMode(this.label);
  final String label;
}

/// Test result export - three modes (specific test / subject-wise /
/// multi-subject combined), each producing its own column shape, but all
/// sharing the same batch/roster resolution, the same [computeSubjectResults]/
/// [computeCombinedResults] calculation engine the Set 15 Results screens
/// use on-screen (`features/results/data/result_calculator.dart` - Set 20
/// refactored this export to call it directly instead of a separate,
/// less rigorous ad-hoc calculation - see docs/database-architecture.md's
/// "Reports & Exports (Set 20)"), and the same PDF/Excel/DOCX rendering
/// via [ExportService].
class TestResultExportScreen extends ConsumerStatefulWidget {
  const TestResultExportScreen({super.key});

  @override
  ConsumerState<TestResultExportScreen> createState() =>
      _TestResultExportScreenState();
}

class _TestResultExportScreenState
    extends ConsumerState<TestResultExportScreen> {
  TestReportMode _mode = TestReportMode.specificTest;
  String? _batchId;

  // Mode 1 & 2 (single subject scope).
  String? _subject;
  String? _specificTestId;
  final Set<String> _subjectWiseTestIds = {};

  // Mode 3 (one test per selected subject).
  final Set<String> _multiSubjects = {};
  final Map<String, String?> _subjectTestChoice = {};

  bool _includeRank = true;
  bool _includeTotal = true;
  bool _includePercentage = true;
  bool _sortByPercentage = true;
  ExportFormat _format = ExportFormat.pdf;
  ReportOrientation _orientation = ReportOrientation.auto;
  String? _layoutTemplateId;
  bool _isGenerating = false;

  void _resetSelections() {
    _subject = null;
    _specificTestId = null;
    _subjectWiseTestIds.clear();
    _multiSubjects.clear();
    _subjectTestChoice.clear();
  }

  @override
  Widget build(BuildContext context) {
    final batchesAsync = ref.watch(allBatchesProvider);
    final testsAsync = _batchId == null
        ? null
        : ref.watch(batchTestsProvider(_batchId!));

    return Scaffold(
      appBar: AppBar(title: const Text('Test result export')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            DropdownButtonFormField<TestReportMode>(
              initialValue: _mode,
              decoration: const InputDecoration(labelText: 'Report mode'),
              items: [
                for (final mode in TestReportMode.values)
                  DropdownMenuItem(value: mode, child: Text(mode.label)),
              ],
              onChanged: (mode) => setState(() {
                _mode = mode ?? _mode;
                _resetSelections();
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            batchesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (error, stackTrace) => const SizedBox.shrink(),
              data: (batches) => DropdownButtonFormField<String?>(
                initialValue: _batchId,
                decoration: const InputDecoration(labelText: 'Batch'),
                items: [
                  for (final batch in batches)
                    DropdownMenuItem<String?>(
                      value: batch.batchId,
                      child: Text(batch.name),
                    ),
                ],
                onChanged: (value) => setState(() {
                  _batchId = value;
                  _resetSelections();
                }),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_batchId != null && testsAsync != null)
              testsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: LinearProgressIndicator(),
                ),
                error: (error, stackTrace) =>
                    Text('Could not load tests.\n$error'),
                data: (tests) => _ModeSelector(
                  mode: _mode,
                  tests: tests,
                  subject: _subject,
                  onSubjectChanged: (value) => setState(() {
                    _subject = value;
                    _specificTestId = null;
                    _subjectWiseTestIds.clear();
                  }),
                  specificTestId: _specificTestId,
                  onSpecificTestChanged: (value) =>
                      setState(() => _specificTestId = value),
                  subjectWiseTestIds: _subjectWiseTestIds,
                  onSubjectWiseTestsChanged: (ids) => setState(() {
                    _subjectWiseTestIds
                      ..clear()
                      ..addAll(ids);
                  }),
                  multiSubjects: _multiSubjects,
                  onMultiSubjectsChanged: (subjects) => setState(() {
                    _multiSubjects
                      ..clear()
                      ..addAll(subjects);
                    _subjectTestChoice.removeWhere(
                      (subject, _) => !subjects.contains(subject),
                    );
                  }),
                  subjectTestChoice: _subjectTestChoice,
                  onSubjectTestChoiceChanged: (subject, testId) =>
                      setState(() => _subjectTestChoice[subject] = testId),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            Text('Columns', style: Theme.of(context).textTheme.titleMedium),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Rank'),
              value: _includeRank,
              onChanged: (value) =>
                  setState(() => _includeRank = value ?? true),
            ),
            if (_mode != TestReportMode.specificTest) ...[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Total'),
                value: _includeTotal,
                onChanged: (value) =>
                    setState(() => _includeTotal = value ?? true),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Percentage'),
                value: _includePercentage,
                onChanged: (value) =>
                    setState(() => _includePercentage = value ?? true),
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sort by percentage, highest first'),
              subtitle: const Text(
                'Off sorts alphabetically by student name instead',
              ),
              value: _sortByPercentage,
              onChanged: (value) => setState(() => _sortByPercentage = value),
            ),
            const SizedBox(height: AppSpacing.md),
            FormatPicker(
              value: _format,
              onChanged: (format) => setState(() => _format = format),
            ),
            const SizedBox(height: AppSpacing.md),
            OrientationPicker(
              value: _orientation,
              onChanged: (o) => setState(() => _orientation = o),
            ),
            const SizedBox(height: AppSpacing.md),
            ReportLayoutPicker(
              value: _layoutTemplateId,
              onChanged: (id) => setState(() => _layoutTemplateId = id),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Generate export',
              icon: Icons.file_download_outlined,
              isLoading: _isGenerating,
              onPressed: _canGenerate ? _generate : null,
            ),
          ],
        ),
      ),
    );
  }

  bool get _canGenerate {
    if (_batchId == null) return false;
    return switch (_mode) {
      TestReportMode.specificTest => _specificTestId != null,
      TestReportMode.subjectWise => _subjectWiseTestIds.isNotEmpty,
      TestReportMode.multiSubject =>
        _multiSubjects.isNotEmpty &&
            _multiSubjects.every(
              (subject) => _subjectTestChoice[subject] != null,
            ),
    };
  }

  Future<void> _generate() async {
    setState(() => _isGenerating = true);
    try {
      final students = await ref.read(studentRepositoryProvider).getAll();
      final roster =
          students.where((s) => s.batchId == _batchId && s.active).toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      final allResults = await ref.read(testResultRepositoryProvider).getAll();
      final allTests = await ref.read(testRepositoryProvider).getAll();
      // Fetched fresh, baked into a one-time snapshot - see
      // ReportBranding's doc comment for why this keeps an already
      // generated report unaffected by a later template edit.
      final branding = _layoutTemplateId == null
          ? null
          : (await ref
                    .read(reportLayoutTemplateRepositoryProvider)
                    .getById(_layoutTemplateId!))
                ?.toBranding();

      final dataset = switch (_mode) {
        TestReportMode.specificTest => _buildSpecificTest(
          roster,
          allResults,
          allTests,
          branding,
        ),
        TestReportMode.subjectWise => _buildSubjectWise(
          roster,
          allResults,
          allTests,
          branding,
        ),
        TestReportMode.multiSubject => _buildMultiSubject(
          roster,
          allResults,
          allTests,
          branding,
        ),
      };

      await const ExportService().export(
        dataset,
        _format,
        fileName: 'test_result',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              friendlyErrorText('Could not generate the export.\n$error'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  /// Reuses Set 15's `computeSubjectResults` - the exact same engine
  /// `TestResultScreen` (`features/results/`) uses on-screen - instead of
  /// re-deriving percentage/rank here (Set 20 sections 7-8, 19: "do not
  /// duplicate ranking logic... reuse computeSubjectResults"). This also
  /// fixes what the pre-Set-20 version of this method never had a bug in:
  /// a single test's own `TestResult.isAbsent` was already correctly
  /// distinct from "no result yet".
  ExportDataset _buildSpecificTest(
    List<StudentProfile> roster,
    List<TestResult> allResults,
    List<TestDefinition> allTests,
    ReportBranding? branding,
  ) {
    final test = allTests.firstWhere((t) => t.testId == _specificTestId);
    final results = allResults.where((r) => r.testId == test.testId).toList();
    final rows = computeSubjectResults(test: test, students: roster, results: results);
    _sortRows(rows, nameOf: (r) => r.student.name, percentageOf: (r) => r.percentage);

    return ExportDataset(
      title: 'Test Result - ${test.title}',
      subtitle:
          '${test.subject} | ${test.chapterTopic} | ${dateKey(test.date)}',
      columns: [
        'Student Name',
        if (_includeRank) 'Rank',
        'Obtained Marks',
        'Total Marks',
        'Percentage',
      ],
      rows: [
        for (final row in rows)
          [
            row.student.name,
            if (_includeRank) (row.rank == null ? '-' : '${row.rank}'),
            _cellLabel(row.cell),
            row.totalMarks.toStringAsFixed(0),
            row.percentage == null ? '-' : '${row.percentage!.toStringAsFixed(1)}%',
          ],
      ],
      orientation: _orientation,
      branding: branding,
    );
  }

  /// Reuses Set 15's `computeCombinedResults` - mathematically identical
  /// whether the several tests being combined are all the same subject
  /// (this mode) or one per different subject (`_buildMultiSubject`
  /// below); the engine only ever asks "does this student have a complete
  /// mark in every one of these tests", never why they were chosen
  /// together. This directly fixes the pre-Set-20 bug where
  /// `combineMarks` alone (with no completeness gate) silently gave every
  /// student here a percentage and a rank even when absent from one test
  /// or never marked at all - see docs/database-architecture.md's
  /// "Reports & Exports (Set 20)".
  ExportDataset _buildSubjectWise(
    List<StudentProfile> roster,
    List<TestResult> allResults,
    List<TestDefinition> allTests,
    ReportBranding? branding,
  ) {
    final tests =
        allTests.where((t) => _subjectWiseTestIds.contains(t.testId)).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final rows = computeCombinedResults(tests: tests, students: roster, allResults: allResults);
    _sortRows(rows, nameOf: (r) => r.student.name, percentageOf: (r) => r.percentage);

    return ExportDataset(
      title: 'Test Result - Subject-wise',
      subtitle:
          '${tests.isEmpty ? '' : tests.first.subject} | ${tests.length} test(s)',
      columns: [
        'Student',
        if (_includeRank) 'Rank',
        for (final test in tests) test.title,
        if (_includeTotal) 'Total',
        if (_includePercentage) 'Percentage',
      ],
      rows: [
        for (final row in rows)
          [
            row.student.name,
            if (_includeRank) (row.rank == null ? '-' : '${row.rank}'),
            for (final cell in row.cells) _cellLabel(cell),
            if (_includeTotal)
              (row.totalObtained == null ? '-' : row.totalObtained!.toStringAsFixed(1)),
            if (_includePercentage)
              (row.percentage == null ? '-' : '${row.percentage!.toStringAsFixed(1)}%'),
          ],
      ],
      orientation: _orientation,
      branding: branding,
    );
  }

  /// Same engine as [_buildSubjectWise] - see that method's doc comment.
  /// Each subject's own real test (never a fabricated shared test id -
  /// Set 20 sections 10, 12) is picked via [_subjectTestChoice].
  ExportDataset _buildMultiSubject(
    List<StudentProfile> roster,
    List<TestResult> allResults,
    List<TestDefinition> allTests,
    ReportBranding? branding,
  ) {
    final subjects = _multiSubjects.toList()..sort();
    final tests = [
      for (final subject in subjects)
        allTests.firstWhere((t) => t.testId == _subjectTestChoice[subject]),
    ];
    final rows = computeCombinedResults(tests: tests, students: roster, allResults: allResults);
    _sortRows(rows, nameOf: (r) => r.student.name, percentageOf: (r) => r.percentage);

    return ExportDataset(
      title: 'Test Result - Multi-subject Combined',
      subtitle: subjects.join(', '),
      columns: [
        'Student',
        if (_includeRank) 'Rank',
        ...subjects,
        if (_includeTotal) 'Total',
        if (_includePercentage) 'Percentage',
      ],
      rows: [
        for (final row in rows)
          [
            row.student.name,
            if (_includeRank) (row.rank == null ? '-' : '${row.rank}'),
            for (final cell in row.cells) _cellLabel(cell),
            if (_includeTotal)
              (row.totalObtained == null ? '-' : row.totalObtained!.toStringAsFixed(1)),
            if (_includePercentage)
              (row.percentage == null ? '-' : '${row.percentage!.toStringAsFixed(1)}%'),
          ],
      ],
      orientation: _orientation,
      branding: branding,
    );
  }

  /// [SubjectCell.status]'s display text - "Absent" is never confused
  /// with "-" (not yet entered), matching Set 14/15's own distinction.
  String _cellLabel(SubjectCell cell) => switch (cell.status) {
    CellStatus.present => cell.obtainedMarks!.toStringAsFixed(1),
    CellStatus.absent => 'Absent',
    CellStatus.missing => '-',
  };

  /// Sorts by percentage descending (nulls - absent/incomplete/no result -
  /// last) when requested, otherwise alphabetically by student name.
  /// Ranks were already computed (by `computeSubjectResults`/
  /// `computeCombinedResults`, order-independent) before this ever runs,
  /// so re-sorting for display never changes what rank a row shows.
  /// Generic over [SubjectResultRow]/[CombinedResultRow] - they only need
  /// to expose a name and a percentage.
  void _sortRows<T>(
    List<T> rows, {
    required String Function(T) nameOf,
    required double? Function(T) percentageOf,
  }) {
    if (!_sortByPercentage) {
      rows.sort((a, b) => nameOf(a).compareTo(nameOf(b)));
      return;
    }
    rows.sort((a, b) {
      final percentageA = percentageOf(a);
      final percentageB = percentageOf(b);
      if (percentageA == null && percentageB == null) {
        return nameOf(a).compareTo(nameOf(b));
      }
      if (percentageA == null) return 1;
      if (percentageB == null) return -1;
      return percentageB.compareTo(percentageA);
    });
  }

}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.mode,
    required this.tests,
    required this.subject,
    required this.onSubjectChanged,
    required this.specificTestId,
    required this.onSpecificTestChanged,
    required this.subjectWiseTestIds,
    required this.onSubjectWiseTestsChanged,
    required this.multiSubjects,
    required this.onMultiSubjectsChanged,
    required this.subjectTestChoice,
    required this.onSubjectTestChoiceChanged,
  });

  final TestReportMode mode;
  final List<TestDefinition> tests;
  final String? subject;
  final ValueChanged<String?> onSubjectChanged;
  final String? specificTestId;
  final ValueChanged<String?> onSpecificTestChanged;
  final Set<String> subjectWiseTestIds;
  final ValueChanged<Set<String>> onSubjectWiseTestsChanged;
  final Set<String> multiSubjects;
  final ValueChanged<Set<String>> onMultiSubjectsChanged;
  final Map<String, String?> subjectTestChoice;
  final void Function(String subject, String? testId)
  onSubjectTestChoiceChanged;

  String _testLabel(TestDefinition test) =>
      '${test.title} (${test.chapterTopic}) - ${dateKey(test.date)}';

  @override
  Widget build(BuildContext context) {
    final subjects = tests.map((t) => t.subject).toSet().toList()..sort();

    return switch (mode) {
      TestReportMode.specificTest || TestReportMode.subjectWise => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String?>(
            initialValue: subject,
            decoration: const InputDecoration(labelText: 'Subject'),
            items: [
              for (final s in subjects)
                DropdownMenuItem<String?>(value: s, child: Text(s)),
            ],
            onChanged: onSubjectChanged,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (subject != null)
            mode == TestReportMode.specificTest
                ? DropdownButtonFormField<String?>(
                    initialValue: specificTestId,
                    decoration: const InputDecoration(labelText: 'Test'),
                    items: [
                      for (final test in tests.where(
                        (t) => t.subject == subject,
                      ))
                        DropdownMenuItem<String?>(
                          value: test.testId,
                          child: Text(_testLabel(test)),
                        ),
                    ],
                    onChanged: onSpecificTestChanged,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tests',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      for (final test in tests.where(
                        (t) => t.subject == subject,
                      ))
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(_testLabel(test)),
                          value: subjectWiseTestIds.contains(test.testId),
                          onChanged: (selected) {
                            final next = Set<String>.from(subjectWiseTestIds);
                            if (selected ?? false) {
                              next.add(test.testId);
                            } else {
                              next.remove(test.testId);
                            }
                            onSubjectWiseTestsChanged(next);
                          },
                        ),
                    ],
                  ),
        ],
      ),
      TestReportMode.multiSubject => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Subjects', style: Theme.of(context).textTheme.titleMedium),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (final s in subjects)
                FilterChip(
                  label: Text(s),
                  selected: multiSubjects.contains(s),
                  onSelected: (selected) {
                    final next = Set<String>.from(multiSubjects);
                    if (selected) {
                      next.add(s);
                    } else {
                      next.remove(s);
                    }
                    onMultiSubjectsChanged(next);
                  },
                ),
            ],
          ),
          for (final s in multiSubjects.toList()..sort())
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: DropdownButtonFormField<String?>(
                initialValue: subjectTestChoice[s],
                decoration: InputDecoration(labelText: '$s test'),
                items: [
                  for (final test in tests.where((t) => t.subject == s))
                    DropdownMenuItem<String?>(
                      value: test.testId,
                      child: Text(_testLabel(test)),
                    ),
                ],
                onChanged: (testId) => onSubjectTestChoiceChanged(s, testId),
              ),
            ),
        ],
      ),
    };
  }
}
