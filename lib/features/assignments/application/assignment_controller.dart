import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/notification_hook.dart';
import '../../auth/application/auth_providers.dart';
import '../data/assignment.dart';
import '../data/assignment_repository.dart';

class AssignmentFailure implements Exception {
  const AssignmentFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

final assignmentControllerProvider = Provider<AssignmentController>((ref) => AssignmentController(ref));

class AssignmentController {
  AssignmentController(this._ref);

  final Ref _ref;

  Future<void> createAssignment({
    required String batchId,
    required String subject,
    required String title,
    required String description,
    required DateTime assignedDate,
    required DateTime dueDate,
  }) async {
    final teacher = _ref.read(currentUserAccountProvider).valueOrNull;
    if (teacher == null) throw const AssignmentFailure('Please sign in again.');

    try {
      final now = DateTime.now();
      final id = await _ref
          .read(assignmentRepositoryProvider)
          .add(
            Assignment(
              assignmentId: '',
              batchId: batchId,
              subject: subject.trim(),
              title: title.trim(),
              description: description.trim(),
              assignedDate: assignedDate,
              dueDate: dueDate,
              status: AssignmentStatus.active,
              teacherRemark: null,
              createdBy: teacher.uid,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await recordNotificationEvent(
        _ref,
        type: NotificationEventType.assignment,
        batchId: batchId,
        title: 'New assignment: $title',
        body: description.trim(),
        relatedId: id,
      );
    } catch (_) {
      throw const AssignmentFailure('Could not create assignment. Please try again.');
    }
  }

  Future<void> setStatus(Assignment existing, {required AssignmentStatus status, required String? teacherRemark}) async {
    try {
      await _ref.read(assignmentRepositoryProvider).updateFields(existing.assignmentId, {
        'status': status.name,
        'teacherRemark': teacherRemark?.trim(),
        'updatedAt': Timestamp.now(),
      });
    } catch (_) {
      throw const AssignmentFailure('Could not update assignment. Please try again.');
    }
  }
}
