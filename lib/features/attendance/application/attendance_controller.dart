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
  /// [academicSessionId]/[classId] are the selected batch's own, snapshotted
  /// at write time (see [StudentAttendanceRecord]'s doc comment).
  Future<void> markStudentAttendance({
    required String batchId,
    required String academicSessionId,
    required String classId,
    required DateTime date,
    required Map<String, AttendanceStatus> records,
  }) async {
    final admin = _ref.read(currentUserAccountProvider).valueOrNull;
    if (admin == null) throw const AttendanceFailure('Please sign in again.');

    final day = dateOnly(date);
    final key = dateKey(day);
    final now = DateTime.now();
    final recordId = '${batchId}_$key';

    try {
      final existing = await _ref
          .read(studentAttendanceRepositoryProvider)
          .getById(recordId);
      await _ref
          .read(studentAttendanceRepositoryProvider)
          .set(
            recordId,
            StudentAttendanceRecord(
              recordId: recordId,
              batchId: batchId,
              dateKey: key,
              date: day,
              academicSessionId: academicSessionId,
              classId: classId,
              records: records,
              createdBy: existing?.createdBy ?? admin.uid,
              updatedBy: admin.uid,
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

  /// Marks (or corrects) every given teacher's attendance for [date] in a
  /// single atomic `WriteBatch` commit - one network round-trip for the
  /// whole day's staff, not one write per teacher (Set 13 spec: "use an
  /// efficient batch write... do not make one unnecessary network write
  /// per [record] if the architecture can safely batch them"). Each
  /// teacher's record still preserves its own `createdAt`/`createdBy` on
  /// re-mark, exactly like [markStudentAttendance].
  Future<void> markTeacherAttendanceBulk({
    required DateTime date,
    required Map<String, AttendanceStatus> statuses,
  }) async {
    final admin = _ref.read(currentUserAccountProvider).valueOrNull;
    if (admin == null) throw const AttendanceFailure('Please sign in again.');

    final day = dateOnly(date);
    final key = dateKey(day);
    final now = DateTime.now();

    try {
      final repo = _ref.read(teacherAttendanceRepositoryProvider);
      final writeBatch = repo.collection.firestore.batch();

      for (final entry in statuses.entries) {
        final teacherUid = entry.key;
        final recordId = '${teacherUid}_$key';
        final existing = await repo.getById(recordId);
        final record = TeacherAttendanceRecord(
          recordId: recordId,
          teacherUid: teacherUid,
          dateKey: key,
          date: day,
          status: entry.value,
          createdBy: existing?.createdBy ?? admin.uid,
          updatedBy: admin.uid,
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
        );
        writeBatch.set(repo.collection.doc(recordId), record.toMap());
      }

      await writeBatch.commit();
    } catch (_) {
      throw const AttendanceFailure(
        'Could not save attendance. Please try again.',
      );
    }
  }
}
