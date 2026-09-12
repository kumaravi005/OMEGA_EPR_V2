import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/features/attendance/data/attendance_stats.dart';
import 'package:omega_epr_v2/features/attendance/data/student_attendance_record.dart';

void main() {
  group('computeAttendanceStats', () {
    test('tallies total/present/absent and computes a percentage', () {
      final stats = computeAttendanceStats(const [
        AttendanceStatus.present,
        AttendanceStatus.present,
        AttendanceStatus.absent,
        AttendanceStatus.present,
      ]);

      expect(stats.total, 4);
      expect(stats.present, 3);
      expect(stats.absent, 1);
      expect(stats.percentage, 75.0);
    });

    test('percentage is null (not zero) when there are no records yet', () {
      final stats = computeAttendanceStats(const []);
      expect(stats.total, 0);
      expect(stats.present, 0);
      expect(stats.absent, 0);
      expect(stats.percentage, isNull);
    });

    test('100% present and 0% present are both computed correctly', () {
      final allPresent = computeAttendanceStats(const [
        AttendanceStatus.present,
        AttendanceStatus.present,
      ]);
      expect(allPresent.percentage, 100.0);

      final allAbsent = computeAttendanceStats(const [
        AttendanceStatus.absent,
        AttendanceStatus.absent,
      ]);
      expect(allAbsent.percentage, 0.0);
    });
  });
}
