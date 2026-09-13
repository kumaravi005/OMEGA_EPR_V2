import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/notification_hook.dart';
import '../../auth/application/auth_providers.dart';
import '../data/academic_work.dart';
import '../data/academic_work_repository.dart';

class AcademicWorkFailure implements Exception {
  const AcademicWorkFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

final academicWorkControllerProvider = Provider<AcademicWorkController>(
  (ref) => AcademicWorkController(ref),
);

/// Admin-only (see firestore.rules and the doc comment on
/// `academicWorkUpdateIsValid`) - Set 16 spec section 8's own fallback:
/// "if the current architecture cannot safely determine teacher batch
/// authorization, allow Admin creation and keep teacher creation
/// disabled". `TeacherProfile.subjectIds` only says which SUBJECTS a
/// teacher may teach, never which BATCHES they may write to - Set 12
/// deliberately left that link unbuilt, and Set 16 does not invent one
/// just to unlock teacher-side creation.
class AcademicWorkController {
  AcademicWorkController(this._ref);

  final Ref _ref;

  /// Creates a new homework/assignment as either `draft` or `published`
  /// (never pre-`closed` - that only makes sense as a later transition,
  /// see [setStatus]).
  Future<void> create({
    required AcademicWorkType type,
    required String academicSessionId,
    required String classId,
    required String batchId,
    required String subjectId,
    required String subjectName,
    required String title,
    String? description,
    required DateTime assignedDate,
    required DateTime dueDate,
    required AcademicWorkStatus status,
  }) async {
    if (dueDate.isBefore(assignedDate)) {
      throw const AcademicWorkFailure(
        'Due date cannot be before the assigned date.',
      );
    }
    if (status == AcademicWorkStatus.closed) {
      throw const AcademicWorkFailure(
        'A new item cannot be created already closed.',
      );
    }
    final admin = _ref.read(currentUserAccountProvider).valueOrNull;
    if (admin == null) {
      throw const AcademicWorkFailure('Please sign in again.');
    }

    try {
      final now = DateTime.now();
      final id = await _ref
          .read(academicWorkRepositoryProvider)
          .add(
            AcademicWork(
              workId: '',
              type: type,
              academicSessionId: academicSessionId,
              classId: classId,
              batchId: batchId,
              subjectId: subjectId,
              subject: subjectName.trim(),
              title: title.trim(),
              description: _blankToNull(description),
              assignedDate: assignedDate,
              dueDate: dueDate,
              status: status,
              createdBy: admin.uid,
              createdAt: now,
              updatedAt: now,
            ),
          );
      if (status == AcademicWorkStatus.published) {
        await _notify(type, batchId, title, description, id);
      }
    } catch (error) {
      if (error is AcademicWorkFailure) rethrow;
      throw const AcademicWorkFailure(
        'Could not save this item. Please try again.',
      );
    }
  }

  /// Edits title/description/dates - never the academic session/class/
  /// batch/subject references, which stay fixed once created (Set 16
  /// spec: "historical academic-work records must not change... the
  /// record must preserve its original session/class/batch/subject
  /// references").
  Future<void> update({
    required AcademicWork existing,
    required String title,
    String? description,
    required DateTime assignedDate,
    required DateTime dueDate,
  }) async {
    if (dueDate.isBefore(assignedDate)) {
      throw const AcademicWorkFailure(
        'Due date cannot be before the assigned date.',
      );
    }
    try {
      await _ref
          .read(academicWorkRepositoryProvider)
          .set(
            existing.workId,
            AcademicWork(
              workId: existing.workId,
              type: existing.type,
              academicSessionId: existing.academicSessionId,
              classId: existing.classId,
              batchId: existing.batchId,
              subjectId: existing.subjectId,
              subject: existing.subject,
              title: title.trim(),
              description: _blankToNull(description),
              assignedDate: assignedDate,
              dueDate: dueDate,
              status: existing.status,
              createdBy: existing.createdBy,
              createdAt: existing.createdAt,
              updatedAt: DateTime.now(),
            ),
          );
    } catch (error) {
      if (error is AcademicWorkFailure) rethrow;
      throw const AcademicWorkFailure(
        'Could not save changes. Please try again.',
      );
    }
  }

  /// Draft -> Published -> Closed, or back - the rule allows any of the
  /// three values in either direction (unlike Set 14's one-way
  /// `resultPublished`), since an admin may legitimately need to
  /// un-publish a mistake or reopen a closed item.
  Future<void> setStatus(AcademicWork existing, AcademicWorkStatus status) async {
    try {
      await _ref.read(academicWorkRepositoryProvider).set(
        existing.workId,
        AcademicWork(
          workId: existing.workId,
          type: existing.type,
          academicSessionId: existing.academicSessionId,
          classId: existing.classId,
          batchId: existing.batchId,
          subjectId: existing.subjectId,
          subject: existing.subject,
          title: existing.title,
          description: existing.description,
          assignedDate: existing.assignedDate,
          dueDate: existing.dueDate,
          status: status,
          createdBy: existing.createdBy,
          createdAt: existing.createdAt,
          updatedAt: DateTime.now(),
        ),
      );
      if (status == AcademicWorkStatus.published &&
          existing.status != AcademicWorkStatus.published) {
        await _notify(
          existing.type,
          existing.batchId,
          existing.title,
          existing.description,
          existing.workId,
        );
      }
    } catch (_) {
      throw const AcademicWorkFailure(
        'Could not update the status. Please try again.',
      );
    }
  }

  Future<void> _notify(
    AcademicWorkType type,
    String batchId,
    String title,
    String? description,
    String relatedId,
  ) {
    return recordNotificationEvent(
      _ref,
      type: type == AcademicWorkType.homework
          ? NotificationEventType.homework
          : NotificationEventType.assignment,
      batchId: batchId,
      title: '${type == AcademicWorkType.homework ? 'New homework' : 'New assignment'}: $title',
      body: description?.trim() ?? '',
      relatedId: relatedId,
    );
  }

  String? _blankToNull(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();
}
