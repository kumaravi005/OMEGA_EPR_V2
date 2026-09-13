import '../../../core/utils/marks_combiner.dart';
import '../../../core/utils/ranking.dart';
import '../../student/data/student_profile.dart';
import '../../tests/data/test_definition.dart';
import '../../tests/data/test_result.dart';

/// One student's marks state for a single subject/test - the building
/// block both [SubjectResultRow] (one subject) and [CombinedResultRow]
/// (several subjects, one cell each) are made of. Distinguishing
/// [CellStatus.absent] from [CellStatus.missing] is exactly the "Absent
/// != zero, and neither is the same as not-yet-entered" rule the Set 14/
/// 15 specs require - never collapsed into a single "no marks" state.
enum CellStatus { present, absent, missing }

class SubjectCell {
  const SubjectCell.present(double marks)
    : status = CellStatus.present,
      obtainedMarks = marks;

  const SubjectCell.absent() : status = CellStatus.absent, obtainedMarks = null;

  const SubjectCell.missing()
    : status = CellStatus.missing,
      obtainedMarks = null;

  final CellStatus status;

  /// Only non-null when [status] is [CellStatus.present].
  final double? obtainedMarks;

  factory SubjectCell.fromResult(TestResult? result) {
    if (result == null) return const SubjectCell.missing();
    if (result.isAbsent) return const SubjectCell.absent();
    return SubjectCell.present(result.obtainedMarks!);
  }
}

/// The overall state of one student's result - complete only when every
/// relevant cell is [CellStatus.present]. Absent takes priority over
/// incomplete when both occur (Set 15 spec: "prefer subject cell =
/// Absent, overall result status = Incomplete / Absent") since a
/// deliberate absence is a more definite outcome than a simply
/// not-yet-entered mark.
enum ResultStatus {
  complete,
  absent,
  incomplete;

  String get label => switch (this) {
    ResultStatus.complete => 'Complete',
    ResultStatus.absent => 'Absent',
    ResultStatus.incomplete => 'Incomplete',
  };

  static ResultStatus fromCells(Iterable<SubjectCell> cells) {
    if (cells.any((c) => c.status == CellStatus.absent)) {
      return ResultStatus.absent;
    }
    if (cells.any((c) => c.status == CellStatus.missing)) {
      return ResultStatus.incomplete;
    }
    return ResultStatus.complete;
  }
}

/// One student's result for a single test (equivalently, a single
/// subject - a Set 14 test always belongs to exactly one subject).
/// [rank] is `null` unless [status] is [ResultStatus.complete] - an
/// absent or not-yet-entered student is never assigned a rank number.
class SubjectResultRow {
  const SubjectResultRow({
    required this.student,
    required this.cell,
    required this.totalMarks,
    required this.percentage,
    required this.rank,
  });

  final StudentProfile student;
  final SubjectCell cell;
  final double totalMarks;

  /// `null` unless [status] is [ResultStatus.complete].
  final double? percentage;
  final int? rank;

  ResultStatus get status => ResultStatus.fromCells([cell]);
}

/// Computes one test's result for every given [students] - ranked by
/// percentage (competition ranking, ties share a rank) among students
/// with a complete (present, non-absent) mark only.
List<SubjectResultRow> computeSubjectResults({
  required TestDefinition test,
  required List<StudentProfile> students,
  required List<TestResult> results,
}) {
  final resultByStudent = {for (final r in results) r.studentUid: r};
  final cells = [
    for (final student in students)
      SubjectCell.fromResult(resultByStudent[student.uid]),
  ];
  final percentages = [
    for (final cell in cells)
      cell.status == CellStatus.present
          ? _percentageOf(cell.obtainedMarks!, test.totalMarks)
          : null,
  ];
  final ranks = rankByPercentage(percentages);

  return [
    for (var i = 0; i < students.length; i++)
      SubjectResultRow(
        student: students[i],
        cell: cells[i],
        totalMarks: test.totalMarks,
        percentage: percentages[i],
        rank: ranks[i],
      ),
  ];
}

/// One student's combined result across several subjects/tests - the
/// same academic context (session/class/batch), each subject its own
/// test (Set 14: "do not assume every subject shares the same test id").
/// [cells] is parallel to the `tests` list passed to
/// [computeCombinedResults], so a caller can render one column per
/// subject in that same order. [totalObtained]/[totalMaximum]/
/// [percentage]/[rank] are all `null` unless [status] is
/// [ResultStatus.complete] - "do not calculate a misleading final
/// percentage/rank" for an absent or incomplete student (Set 15 spec).
class CombinedResultRow {
  const CombinedResultRow({
    required this.student,
    required this.cells,
    required this.status,
    required this.totalObtained,
    required this.totalMaximum,
    required this.percentage,
    required this.rank,
  });

  final StudentProfile student;
  final List<SubjectCell> cells;
  final ResultStatus status;
  final double? totalObtained;
  final double? totalMaximum;
  final double? percentage;
  final int? rank;
}

/// Computes a combined multi-subject result for every given [students]
/// across [tests] (one per selected subject, in display order) - the
/// combined maximum is the sum of each test's own `totalMarks` (Set 15
/// spec: "do not assume every subject has the same maximum marks").
/// Only students with a complete mark in every one of [tests] receive a
/// total/percentage/rank; an absent or missing mark in any single
/// subject marks the whole row absent/incomplete instead (see
/// [ResultStatus.fromCells]).
List<CombinedResultRow> computeCombinedResults({
  required List<TestDefinition> tests,
  required List<StudentProfile> students,
  required List<TestResult> allResults,
}) {
  final resultsByTest = {
    for (final test in tests)
      test.testId: {
        for (final r in allResults.where((r) => r.testId == test.testId))
          r.studentUid: r,
      },
  };

  final rowsWithoutRank = [
    for (final student in students)
      () {
        final cells = [
          for (final test in tests)
            SubjectCell.fromResult(resultsByTest[test.testId]![student.uid]),
        ];
        final status = ResultStatus.fromCells(cells);

        double? totalObtained;
        double? totalMaximum;
        double? percentage;
        if (status == ResultStatus.complete) {
          final maxMarks = [for (final test in tests) test.totalMarks];
          final marks = [for (final cell in cells) cell.obtainedMarks];
          final combined = combineMarks(marks, maxMarks);
          totalObtained = combined.total;
          totalMaximum = maxMarks.fold<double>(0, (sum, m) => sum + m);
          percentage = combined.percentage ?? 0;
        }

        return (
          student: student,
          cells: cells,
          status: status,
          totalObtained: totalObtained,
          totalMaximum: totalMaximum,
          percentage: percentage,
        );
      }(),
  ];

  final ranks = rankByPercentage([
    for (final row in rowsWithoutRank) row.percentage,
  ]);

  return [
    for (var i = 0; i < rowsWithoutRank.length; i++)
      CombinedResultRow(
        student: rowsWithoutRank[i].student,
        cells: rowsWithoutRank[i].cells,
        status: rowsWithoutRank[i].status,
        totalObtained: rowsWithoutRank[i].totalObtained,
        totalMaximum: rowsWithoutRank[i].totalMaximum,
        percentage: rowsWithoutRank[i].percentage,
        rank: ranks[i],
      ),
  ];
}

double _percentageOf(double obtained, double total) =>
    total == 0 ? 0 : (obtained / total) * 100;
