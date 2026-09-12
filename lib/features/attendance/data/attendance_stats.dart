import 'student_attendance_record.dart';

/// Present/absent tally + percentage for one student or teacher over some
/// set of attendance records - always computed on demand from the raw
/// records (Set 13 spec: "calculated from attendance records rather than
/// manually stored totals"), never a maintained counter.
class AttendanceStats {
  const AttendanceStats({required this.total, required this.present});

  final int total;
  final int present;

  int get absent => total - present;

  /// `null` when there is nothing to compute a percentage from yet -
  /// callers should render that as "-", never as 0%.
  double? get percentage => total == 0 ? null : (present / total) * 100;
}

/// Tallies a plain iterable of statuses - the shared building block both
/// a single student/teacher's own history screen and an admin's batch/
/// date-range summary table use, so the present/absent/percentage math
/// is written and tested exactly once.
AttendanceStats computeAttendanceStats(Iterable<AttendanceStatus> statuses) {
  var total = 0;
  var present = 0;
  for (final status in statuses) {
    total++;
    if (status == AttendanceStatus.present) present++;
  }
  return AttendanceStats(total: total, present: present);
}
