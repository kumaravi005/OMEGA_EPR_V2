import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/date_key.dart';
import '../../auth/application/auth_providers.dart';
import '../data/attendance_repository.dart';
import '../data/student_attendance_record.dart';
import '../data/teacher_attendance_record.dart';

class AttendanceFailure implements Exception {
  const AttendanceFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

final attendanceControllerProvider = Provider<AttendanceController>(
  (ref) => AttendanceController(ref),
);

class AttendanceController {
  AttendanceController(this._ref);

  final Ref _ref;

  /// Marks (or corrects) the whole batch's attendance for [date] in one
  /// write - `records` covers every student, never split by subject.
  Future<void> markStudentAttendance({
    required String batchId,
    required DateTime date,
    required Map<String, AttendanceStatus> records,
  }) async {
    final admin = _ref.read(currentUserAccountProvider).valueOrNull;
    if (admin == null) throw const AttendanceFailure('Please sign in again.');

    final day = dateOnly(date);
    final key = dateKey(day);
    final now = DateTime.now();

    try {
      final existing = await _ref
          .read(studentAttendanceRepositoryProvider)
          .getById('${batchId}_$key');
      await _ref
          .read(studentAttendanceRepositoryProvider)
          .set(
            '${batchId}_$key',
            StudentAttendanceRecord(
              recordId: '${batchId}_$key',
              batchId: batchId,
              dateKey: key,
              date: day,
              records: records,
              markedBy: admin.uid,
              createdAt: existing?.createdAt ?? now,
              updatedAt: now,
            ),
          );
    } catch (_) {
      throw const AttendanceFailure(
        'Could not save attendance. Please try again.',
      );
    }
  }

  Future<void> markTeacherAttendance({
    required String teacherUid,
    required DateTime date,
    required AttendanceStatus status,
  }) async {
    final admin = _ref.read(currentUserAccountProvider).valueOrNull;
    if (admin == null) throw const AttendanceFailure('Please sign in again.');

    final day = dateOnly(date);
    final key = dateKey(day);
    final now = DateTime.now();

    try {
      final existing = await _ref
          .read(teacherAttendanceRepositoryProvider)
          .getById('${teacherUid}_$key');
      await _ref
          .read(teacherAttendanceRepositoryProvider)
          .set(
            '${teacherUid}_$key',
            TeacherAttendanceRecord(
              recordId: '${teacherUid}_$key',
              teacherUid: teacherUid,
              dateKey: key,
              date: day,
              status: status,
              markedBy: admin.uid,
              createdAt: existing?.createdAt ?? now,
              updatedAt: now,
            ),
          );
    } catch (_) {
      throw const AttendanceFailure(
        'Could not save attendance. Please try again.',
      );
    }
  }
}
