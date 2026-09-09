import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../data/repositories/firestore_repository.dart';
import 'student_attendance_record.dart';
import 'teacher_attendance_record.dart';

final studentAttendanceRepositoryProvider = Provider<FirestoreRepository<StudentAttendanceRecord>>((ref) {
  return FirestoreRepository<StudentAttendanceRecord>(
    firestore: ref.watch(firestoreProvider),
    collectionPath: FirestoreCollections.attendance,
    fromFirestore: StudentAttendanceRecord.fromMap,
    toFirestore: (record) => record.toMap(),
  );
});

/// All attendance records for one batch, newest first - for a batch's
/// attendance calendar and a student's own history/percentage.
final batchAttendanceProvider = StreamProvider.family<List<StudentAttendanceRecord>, String>((ref, batchId) {
  return ref.watch(studentAttendanceRepositoryProvider).watchAll().map(
    (records) => records.where((r) => r.batchId == batchId).toList()..sort((a, b) => b.date.compareTo(a.date)),
  );
});

final teacherAttendanceRepositoryProvider = Provider<FirestoreRepository<TeacherAttendanceRecord>>((ref) {
  return FirestoreRepository<TeacherAttendanceRecord>(
    firestore: ref.watch(firestoreProvider),
    collectionPath: FirestoreCollections.teacherAttendance,
    fromFirestore: TeacherAttendanceRecord.fromMap,
    toFirestore: (record) => record.toMap(),
  );
});

/// One teacher's own attendance history, newest first.
final teacherOwnAttendanceProvider = StreamProvider.family<List<TeacherAttendanceRecord>, String>((ref, teacherUid) {
  return ref.watch(teacherAttendanceRepositoryProvider).watchAll().map(
    (records) => records.where((r) => r.teacherUid == teacherUid).toList()..sort((a, b) => b.date.compareTo(a.date)),
  );
});
