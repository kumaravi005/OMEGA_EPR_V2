import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_providers.dart';
import '../data/teacher_assignment.dart';
import '../data/teacher_assignment_repository.dart';

/// A clean, user-facing reason a teacher-assignment create/update failed.
/// Never wraps a raw Firebase error message.
class TeacherAssignmentFailure implements Exception {
  const TeacherAssignmentFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

final teacherAssignmentControllerProvider = Provider<TeacherAssignmentController>(
  (ref) => TeacherAssignmentController(ref),
);

class TeacherAssignmentController {
  TeacherAssignmentController(this._ref);

  final Ref _ref;

  /// Creates a new active assignment. Rejects outright if one already
  /// exists for this exact teacher+session+batch+subject combination
  /// (Set 22 section 6), active or not - re-adding a previously
  /// deactivated assignment is done via [setActive], not by creating a
  /// second document, since the deterministic id means it would be the
  /// same document anyway.
  Future<void> createAssignment({
    required String teacherId,
    required String academicSessionId,
    required String classId,
    required String batchId,
    required String subjectId,
  }) async {
    final admin = _ref.read(currentUserAccountProvider).valueOrNull;
    if (admin == null) {
      throw const TeacherAssignmentFailure(
        'Could not identify the signed-in admin. Please try again.',
      );
    }

    final assignmentId = TeacherAssignment.idFor(
      teacherId: teacherId,
      academicSessionId: academicSessionId,
      batchId: batchId,
      subjectId: subjectId,
    );

    try {
      final repo = _ref.read(teacherAssignmentRepositoryProvider);
      final existing = await repo.getById(assignmentId);
      if (existing != null) {
        throw const TeacherAssignmentFailure(
          'This teacher already has an assignment for this session, batch '
          'and subject. Activate it from the list instead of adding it '
          'again.',
        );
      }

      final now = DateTime.now();
      await repo.set(
        assignmentId,
        TeacherAssignment(
          assignmentId: assignmentId,
          teacherId: teacherId,
          academicSessionId: academicSessionId,
          classId: classId,
          batchId: batchId,
          subjectId: subjectId,
          active: true,
          createdBy: admin.uid,
          updatedBy: admin.uid,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } on TeacherAssignmentFailure {
      rethrow;
    } catch (_) {
      throw const TeacherAssignmentFailure(
        'Could not create the assignment. Please try again.',
      );
    }
  }

  /// Activates/deactivates an assignment without touching any other
  /// field - the historical teacherId/session/class/batch/subject
  /// relationship it records is never rewritten (Set 22 sections 7, 18).
  Future<void> setActive(TeacherAssignment existing, bool active) async {
    final admin = _ref.read(currentUserAccountProvider).valueOrNull;
    if (admin == null) {
      throw const TeacherAssignmentFailure(
        'Could not identify the signed-in admin. Please try again.',
      );
    }
    try {
      await _ref
          .read(teacherAssignmentRepositoryProvider)
          .updateFields(existing.assignmentId, {
            'active': active,
            'updatedBy': admin.uid,
            'updatedAt': Timestamp.now(),
          });
    } catch (_) {
      throw const TeacherAssignmentFailure(
        'Could not update the assignment. Please try again.',
      );
    }
  }
}
