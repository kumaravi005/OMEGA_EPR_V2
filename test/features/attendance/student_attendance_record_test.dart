import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/features/attendance/data/student_attendance_record.dart';

void main() {
  test('presentCount and absentCount tally the records map', () {
    final now = DateTime(2026, 9, 10);
    final record = StudentAttendanceRecord(
      recordId: 'batch1_2026-09-10',
      batchId: 'batch1',
      dateKey: '2026-09-10',
      date: now,
      records: const {
        'stu1': AttendanceStatus.present,
        'stu2': AttendanceStatus.present,
        'stu3': AttendanceStatus.absent,
      },
      markedBy: 'admin1',
      createdAt: now,
      updatedAt: now,
    );

    expect(record.presentCount, 2);
    expect(record.absentCount, 1);
  });

  test('round-trips through toMap/fromMap, including the records map', () {
    final now = DateTime(2026, 9, 10);
    final record = StudentAttendanceRecord(
      recordId: 'batch1_2026-09-10',
      batchId: 'batch1',
      dateKey: '2026-09-10',
      date: now,
      records: const {
        'stu1': AttendanceStatus.present,
        'stu2': AttendanceStatus.absent,
      },
      markedBy: 'admin1',
      createdAt: now,
      updatedAt: now,
    );

    final restored = StudentAttendanceRecord.fromMap(
      record.recordId,
      record.toMap(),
    );

    expect(restored.records['stu1'], AttendanceStatus.present);
    expect(restored.records['stu2'], AttendanceStatus.absent);
    expect(restored.batchId, 'batch1');
    expect(restored.dateKey, '2026-09-10');
  });
}
