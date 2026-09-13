import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_providers.dart';
import '../data/notice.dart';
import '../data/notice_repository.dart';

class NoticeFailure implements Exception {
  const NoticeFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

final noticeControllerProvider = Provider<NoticeController>(
  (ref) => NoticeController(ref),
);

/// Admin-only (see firestore.rules) - the only write path for [Notice].
/// Content (title/message/type/expiry) is editable only while still
/// [NoticeStatus.draft]; publishing and closing are one-way (see
/// [Notice]'s class doc comment) and never touch content.
class NoticeController {
  NoticeController(this._ref);

  final Ref _ref;

  /// Creates a new notice as either `draft` or `published` (never
  /// pre-`closed` - matching `AcademicWorkController.create`'s identical
  /// rule).
  Future<void> create({
    required String title,
    required String message,
    required NoticeType type,
    String? otherTypeLabel,
    required NoticeAudience audience,
    required NoticeScope scope,
    String? academicSessionId,
    String? classId,
    String? batchId,
    DateTime? expiresAt,
    required NoticeStatus status,
    bool isPublic = false,
  }) async {
    if (title.trim().isEmpty) {
      throw const NoticeFailure('Title is required.');
    }
    if (message.trim().isEmpty) {
      throw const NoticeFailure('Message is required.');
    }
    if (status == NoticeStatus.closed) {
      throw const NoticeFailure('A new notice cannot be created already closed.');
    }
    if (type == NoticeType.other && (otherTypeLabel == null || otherTypeLabel.trim().isEmpty)) {
      throw const NoticeFailure('Enter a label for the "Other" type.');
    }
    final needsClass = scope == NoticeScope.byClass || scope == NoticeScope.byBatch;
    if (needsClass && (classId == null || classId.trim().isEmpty)) {
      throw const NoticeFailure('Select a class.');
    }
    if (scope == NoticeScope.byBatch && (batchId == null || batchId.trim().isEmpty)) {
      throw const NoticeFailure('Select a batch.');
    }
    if (audience == NoticeAudience.all || audience == NoticeAudience.teachers) {
      if (scope != NoticeScope.institute) {
        throw const NoticeFailure('This audience is always institute-wide.');
      }
    }

    final admin = _ref.read(currentUserAccountProvider).valueOrNull;
    if (admin == null) {
      throw const NoticeFailure('Please sign in again.');
    }

    final now = DateTime.now();
    final targetKey = Notice.computeTargetKey(
      audience: audience,
      scope: scope,
      classId: classId,
      batchId: batchId,
    );

    try {
      await _ref.read(noticeRepositoryProvider).add(
        Notice(
          noticeId: '',
          title: title.trim(),
          message: message.trim(),
          type: type,
          otherTypeLabel: type == NoticeType.other ? otherTypeLabel!.trim() : null,
          audience: audience,
          scope: scope,
          academicSessionId: scope == NoticeScope.institute ? null : academicSessionId,
          classId: scope == NoticeScope.institute ? null : classId,
          batchId: scope == NoticeScope.byBatch ? batchId : null,
          targetKey: targetKey,
          status: status,
          createdBy: admin.uid,
          createdAt: now,
          updatedAt: now,
          publishedAt: status == NoticeStatus.published ? now : null,
          expiresAt: expiresAt,
          isPublic: isPublic,
        ),
      );
    } catch (error) {
      if (error is NoticeFailure) rethrow;
      throw const NoticeFailure('Could not save this notice. Please try again.');
    }
  }

  /// Edits content only - targeting/identity fields are fixed at
  /// creation (see [Notice]'s class doc comment) and only while the
  /// notice is still a draft (Set 17 section 10: admin actions are
  /// "edit draft / publish draft / close published").
  Future<void> edit({
    required Notice existing,
    required String title,
    required String message,
    required NoticeType type,
    String? otherTypeLabel,
    DateTime? expiresAt,
  }) async {
    if (existing.status != NoticeStatus.draft) {
      throw const NoticeFailure('Only a draft notice can be edited.');
    }
    if (title.trim().isEmpty) {
      throw const NoticeFailure('Title is required.');
    }
    if (message.trim().isEmpty) {
      throw const NoticeFailure('Message is required.');
    }
    if (type == NoticeType.other && (otherTypeLabel == null || otherTypeLabel.trim().isEmpty)) {
      throw const NoticeFailure('Enter a label for the "Other" type.');
    }

    try {
      await _ref.read(noticeRepositoryProvider).set(
        existing.noticeId,
        Notice(
          noticeId: existing.noticeId,
          title: title.trim(),
          message: message.trim(),
          type: type,
          otherTypeLabel: type == NoticeType.other ? otherTypeLabel!.trim() : null,
          audience: existing.audience,
          scope: existing.scope,
          academicSessionId: existing.academicSessionId,
          classId: existing.classId,
          batchId: existing.batchId,
          targetKey: existing.targetKey,
          status: existing.status,
          createdBy: existing.createdBy,
          createdAt: existing.createdAt,
          updatedAt: DateTime.now(),
          publishedAt: existing.publishedAt,
          expiresAt: expiresAt,
          isPublic: existing.isPublic,
        ),
      );
    } catch (error) {
      if (error is NoticeFailure) rethrow;
      throw const NoticeFailure('Could not save changes. Please try again.');
    }
  }

  /// Draft -> Published only (one-way - see [Notice]'s class doc
  /// comment). Sets [Notice.publishedAt] to now.
  Future<void> publish(Notice existing) async {
    if (existing.status != NoticeStatus.draft) {
      throw const NoticeFailure('Only a draft notice can be published.');
    }
    final now = DateTime.now();
    try {
      await _ref.read(noticeRepositoryProvider).set(
        existing.noticeId,
        Notice(
          noticeId: existing.noticeId,
          title: existing.title,
          message: existing.message,
          type: existing.type,
          otherTypeLabel: existing.otherTypeLabel,
          audience: existing.audience,
          scope: existing.scope,
          academicSessionId: existing.academicSessionId,
          classId: existing.classId,
          batchId: existing.batchId,
          targetKey: existing.targetKey,
          status: NoticeStatus.published,
          createdBy: existing.createdBy,
          createdAt: existing.createdAt,
          updatedAt: now,
          publishedAt: now,
          expiresAt: existing.expiresAt,
          isPublic: existing.isPublic,
        ),
      );
    } catch (_) {
      throw const NoticeFailure('Could not publish this notice. Please try again.');
    }
  }

  /// Published -> Closed only (one-way). "Do not allow dangerous
  /// destructive deletion of published notifications" (section 10) - this
  /// is the only way a published notice ever stops being active; the
  /// document itself is never deleted (`allow delete: if false`).
  Future<void> close(Notice existing) async {
    if (existing.status != NoticeStatus.published) {
      throw const NoticeFailure('Only a published notice can be closed.');
    }
    try {
      await _ref.read(noticeRepositoryProvider).set(
        existing.noticeId,
        Notice(
          noticeId: existing.noticeId,
          title: existing.title,
          message: existing.message,
          type: existing.type,
          otherTypeLabel: existing.otherTypeLabel,
          audience: existing.audience,
          scope: existing.scope,
          academicSessionId: existing.academicSessionId,
          classId: existing.classId,
          batchId: existing.batchId,
          targetKey: existing.targetKey,
          status: NoticeStatus.closed,
          createdBy: existing.createdBy,
          createdAt: existing.createdAt,
          updatedAt: DateTime.now(),
          publishedAt: existing.publishedAt,
          expiresAt: existing.expiresAt,
          isPublic: existing.isPublic,
        ),
      );
    } catch (_) {
      throw const NoticeFailure('Could not close this notice. Please try again.');
    }
  }

  /// Toggles public-site visibility only (Set 18) - independent of
  /// [NoticeStatus] and reachable at any status, unlike `edit`/`publish`/
  /// `close`. A partial `.update()` (not a full rewrite), matching
  /// `noticePublicVisibilityUpdateIsValid` in firestore.rules, which
  /// restricts it to exactly `isPublic`/`updatedAt`.
  Future<void> setPublicVisibility(Notice existing, bool isPublic) async {
    try {
      await _ref.read(noticeRepositoryProvider).updateFields(
        existing.noticeId,
        {'isPublic': isPublic, 'updatedAt': Timestamp.now()},
      );
    } catch (_) {
      throw const NoticeFailure(
        'Could not update public visibility. Please try again.',
      );
    }
  }
}
