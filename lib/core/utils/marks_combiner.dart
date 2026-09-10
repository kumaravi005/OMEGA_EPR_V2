/// A combined total/percentage across several marks entries - shared by
/// every "several tests -> one row" export mode (subject-wise: several
/// tests in one subject; multi-subject combined: one test per subject).
/// A missing mark (the student wasn't marked for that test) contributes
/// 0 to the total but its max marks still count toward the denominator,
/// so a missing test lowers the percentage rather than being silently
/// excluded from it - "if maximum marks differ, calculate ranking using
/// percentage" only works if every row's percentage is out of the same
/// combined maximum.
class CombinedScore {
  const CombinedScore({required this.total, required this.percentage});

  final double total;

  /// Null only when every entry's max marks is zero (nothing to compute a
  /// percentage out of at all).
  final double? percentage;
}

CombinedScore combineMarks(List<double?> obtainedMarks, List<double> maxMarks) {
  assert(
    obtainedMarks.length == maxMarks.length,
    'Each obtained-marks entry needs a matching max-marks entry',
  );
  final total = obtainedMarks.fold<double>(
    0,
    (sum, marks) => sum + (marks ?? 0),
  );
  final possible = maxMarks.fold<double>(0, (sum, marks) => sum + marks);
  final percentage = possible == 0 ? null : (total / possible) * 100;
  return CombinedScore(total: total, percentage: percentage);
}
