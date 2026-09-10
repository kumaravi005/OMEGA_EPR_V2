import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/notification_hook.dart';
import '../../auth/application/auth_providers.dart';
import '../data/homework.dart';
import '../data/homework_repository.dart';

class HomeworkFailure implements Exception {
  const HomeworkFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

final homeworkControllerProvider = Provider<HomeworkController>(
  (ref) => HomeworkController(ref),
);

class HomeworkController {
  HomeworkController(this._ref);

  final Ref _ref;

  Future<void> createHomework({
    required String batchId,
    required String subject,
    required DateTime date,
    required String description,
    required DateTime dueDate,
  }) async {
    final teacher = _ref.read(currentUserAccountProvider).valueOrNull;
    if (teacher == null) throw const HomeworkFailure('Please sign in again.');

    try {
      final now = DateTime.now();
      final id = await _ref
          .read(homeworkRepositoryProvider)
          .add(
            Homework(
              homeworkId: '',
              batchId: batchId,
              subject: subject.trim(),
              date: date,
              description: description.trim(),
              dueDate: dueDate,
              completionStatus: CompletionStatus.pending,
              remark: null,
              createdBy: teacher.uid,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await recordNotificationEvent(
        _ref,
        type: NotificationEventType.homework,
        batchId: batchId,
        title: 'New homework: $subject',
        body: description.trim(),
        relatedId: id,
      );
    } catch (_) {
      throw const HomeworkFailure(
        'Could not create homework. Please try again.',
      );
    }
  }

  Future<void> setCompletion(
    Homework existing, {
    required CompletionStatus status,
    required String? remark,
  }) async {
    try {
      await _ref
          .read(homeworkRepositoryProvider)
          .updateFields(existing.homeworkId, {
            'completionStatus': status.name,
            'remark': remark?.trim(),
            'updatedAt': Timestamp.now(),
          });
    } catch (_) {
      throw const HomeworkFailure(
        'Could not update homework. Please try again.',
      );
    }
  }
}
