import 'package:cloud_firestore/cloud_firestore.dart';
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
      academicSessionId: 'session2026',
      classId: 'class8',
      records: const {
        'stu1': AttendanceStatus.present,
        'stu2': AttendanceStatus.present,
        'stu3': AttendanceStatus.absent,
      },
      createdBy: 'admin1',
      updatedBy: 'admin1',
      createdAt: now,
      updatedAt: now,
    );

    expect(record.presentCount, 2);
    expect(record.absentCount, 1);
  });

  test(
    'round-trips through toMap/fromMap, including the records map and '
    'Set 13 fields',
    () {
      final now = DateTime(2026, 9, 10);
      final record = StudentAttendanceRecord(
        recordId: 'batch1_2026-09-10',
        batchId: 'batch1',
        dateKey: '2026-09-10',
        date: now,
        academicSessionId: 'session2026',
        classId: 'class8',
        records: const {
          'stu1': AttendanceStatus.present,
          'stu2': AttendanceStatus.absent,
        },
        createdBy: 'admin1',
        updatedBy: 'admin2',
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
      expect(restored.academicSessionId, 'session2026');
      expect(restored.classId, 'class8');
      expect(restored.createdBy, 'admin1');
      expect(restored.updatedBy, 'admin2');
    },
  );

  test(
    'fromMap falls back to the legacy markedBy field for createdBy/'
    'updatedBy, and defaults session/class to empty, on a pre-Set-13 '
    'document',
    () {
      final now = Timestamp.fromDate(DateTime(2025, 4, 1));
      final restored = StudentAttendanceRecord.fromMap('batch1_2025-04-01', {
        'batchId': 'batch1',
        'dateKey': '2025-04-01',
        'date': now,
        'records': {'stu1': 'present'},
        'markedBy': 'admin1',
        'createdAt': now,
        'updatedAt': now,
      });

      expect(restored.academicSessionId, '');
      expect(restored.classId, '');
      expect(restored.createdBy, 'admin1');
      expect(restored.updatedBy, 'admin1');
    },
  );
}
