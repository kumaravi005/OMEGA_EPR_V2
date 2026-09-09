/// Formats a date as "YYYY-MM-DD" - used to build deterministic document
/// IDs (e.g. `<batchId>_<dateKey>` for attendance) so writing the same
/// batch/date twice updates the same record instead of creating a
/// duplicate.
String dateKey(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Midnight of [date], in local time - attendance/homework/test dates are
/// day-granularity, not date-time.
DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
