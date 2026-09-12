import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/features/attendance/data/student_attendance_record.dart'
    show AttendanceStatus;
import 'package:omega_epr_v2/features/attendance/data/teacher_attendance_record.dart';

void main() {
  test('round-trips through toMap/fromMap, including Set 13 fields', () {
    final now = DateTime(2026, 9, 10);
    final record = TeacherAttendanceRecord(
      recordId: 'teacher1_2026-09-10',
      teacherUid: 'teacher1',
      dateKey: '2026-09-10',
      date: now,
      status: AttendanceStatus.present,
      createdBy: 'admin1',
      updatedBy: 'admin2',
      createdAt: now,
      updatedAt: now,
    );

    final restored = TeacherAttendanceRecord.fromMap(
      record.recordId,
      record.toMap(),
    );

    expect(restored.teacherUid, 'teacher1');
    expect(restored.dateKey, '2026-09-10');
    expect(restored.status, AttendanceStatus.present);
    expect(restored.createdBy, 'admin1');
    expect(restored.updatedBy, 'admin2');
  });

  test(
    'fromMap falls back to the legacy markedBy field for createdBy/'
    'updatedBy on a pre-Set-13 document',
    () {
      final now = Timestamp.fromDate(DateTime(2025, 4, 1));
      final restored = TeacherAttendanceRecord.fromMap('teacher1_2025-04-01', {
        'teacherUid': 'teacher1',
        'dateKey': '2025-04-01',
        'date': now,
        'status': 'absent',
        'markedBy': 'admin1',
        'createdAt': now,
        'updatedAt': now,
      });

      expect(restored.status, AttendanceStatus.absent);
      expect(restored.createdBy, 'admin1');
      expect(restored.updatedBy, 'admin1');
    },
  );
}
