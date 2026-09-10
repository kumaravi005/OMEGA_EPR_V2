import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../data/repositories/firestore_repository.dart';
import 'student_attendance_record.dart';
import 'teacher_attendance_record.dart';

final studentAttendanceRepositoryProvider =
    Provider<FirestoreRepository<StudentAttendanceRecord>>((ref) {
      return FirestoreRepository<StudentAttendanceRecord>(
        firestore: ref.watch(firestoreProvider),
        collectionPath: FirestoreCollections.attendance,
        fromFirestore: StudentAttendanceRecord.fromMap,
        toFirestore: (record) => record.toMap(),
      );
    });

/// All attendance records for one batch, newest first - for a batch's
/// attendance calendar and a student's own history/percentage. Filtered
/// server-side (not `watchAll()` + client-side filter): a student's
/// `list` rule branch depends on `batchId` per-document (see
/// firestore.rules), which Firestore can only verify against a query
/// that itself carries the same `.where()` - an unconstrained scan is
/// rejected outright for that branch (see FirestoreRepository.watchWhere).
final batchAttendanceProvider =
    StreamProvider.family<List<StudentAttendanceRecord>, String>((
      ref,
      batchId,
    ) {
      return ref
          .watch(studentAttendanceRepositoryProvider)
          .watchWhere((query) => query.where('batchId', isEqualTo: batchId))
          .map(
            (records) =>
                records.toList()..sort((a, b) => b.date.compareTo(a.date)),
          );
    });

final teacherAttendanceRepositoryProvider =
    Provider<FirestoreRepository<TeacherAttendanceRecord>>((ref) {
      return FirestoreRepository<TeacherAttendanceRecord>(
        firestore: ref.watch(firestoreProvider),
        collectionPath: FirestoreCollections.teacherAttendance,
        fromFirestore: TeacherAttendanceRecord.fromMap,
        toFirestore: (record) => record.toMap(),
      );
    });

/// One teacher's own attendance history, newest first. Filtered
/// server-side - see [batchAttendanceProvider]'s doc comment; the same
/// reasoning applies to `teacherAttendance`'s `teacherUid` field.
final teacherOwnAttendanceProvider =
    StreamProvider.family<List<TeacherAttendanceRecord>, String>((
      ref,
      teacherUid,
    ) {
      return ref
          .watch(teacherAttendanceRepositoryProvider)
          .watchWhere(
            (query) => query.where('teacherUid', isEqualTo: teacherUid),
          )
          .map(
            (records) =>
                records.toList()..sort((a, b) => b.date.compareTo(a.date)),
          );
    });
