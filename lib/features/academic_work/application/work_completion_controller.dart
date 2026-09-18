import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_providers.dart';
import '../data/academic_work.dart';
import '../data/work_completion.dart';
import '../data/work_completion_repository.dart';

class WorkCompletionFailure implements Exception {
  const WorkCompletionFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One student's staged status (and optional remark), before it's saved -
/// the shape [WorkCompletionController.saveBulk] takes for the whole
/// sheet. A student simply absent from the map means "leave their existing
/// record (or lack of one) untouched".
class CompletionEntry {
  const CompletionEntry({required this.status, this.remark});

  final WorkCompletionStatus status;
  final String? remark;
}

final workCompletionControllerProvider = Provider<WorkCompletionController>(
  (ref) => WorkCompletionController(ref),
);

class WorkCompletionController {
  WorkCompletionController(this._ref);

  final Ref _ref;

  static const maxRemarkLength = 200;

  /// Saves the whole sheet in one Firestore `WriteBatch`, writing only the
  /// rows that actually changed against [existing] (keyed by student uid) -
  /// the same "one batch per Save tap" pattern as attendance and test
  /// marks. Every written row resets `seenAt`, so those students are told
  /// again. Returns how many students were updated.
  Future<int> saveBulk({
    required AcademicWork work,
    required Map<String, CompletionEntry> entries,
    required Map<String, WorkCompletion> existing,
  }) async {
    if (work.status == AcademicWorkStatus.draft) {
      throw const WorkCompletionFailure(
        'Publish this item before marking student status.',
      );
    }
    for (final entry in entries.values) {
      if ((entry.remark?.trim().length ?? 0) > maxRemarkLength) {
        throw const WorkCompletionFailure(
          'A remark can be at most $maxRemarkLength characters.',
        );
      }
    }
    final account = _ref.read(currentUserAccountProvider).valueOrNull;
    if (account == null) {
      throw const WorkCompletionFailure('Please sign in again.');
    }

    final changed = <String, CompletionEntry>{
      for (final item in entries.entries)
        if (_differs(existing[item.key], item.value)) item.key: item.value,
    };
    if (changed.isEmpty) return 0;

    try {
      final repo = _ref.read(workCompletionRepositoryProvider);
      final batch = repo.collection.firestore.batch();
      final now = DateTime.now();
      for (final item in changed.entries) {
        final record = WorkCompletion(
          workId: work.workId,
          studentUid: item.key,
          batchId: work.batchId,
          status: item.value.status,
          remark: _blankToNull(item.value.remark),
          markedBy: account.uid,
          markedAt: now,
        );
        batch.set(repo.collection.doc(record.id), record.toMap());
      }
      await batch.commit();
      return changed.length;
    } catch (_) {
      throw const WorkCompletionFailure(
        'Could not save student status. Please try again.',
      );
    }
  }

  /// The signed-in student dismissed the popup for [items] - stamps
  /// `seenAt` so it isn't shown again. The only write a student may make
  /// (enforced by firestore.rules: `seenAt` alone, on their own record).
  Future<void> markSeen(Iterable<WorkCompletion> items) async {
    final unseen = items.where((item) => item.isUnseen).toList();
    if (unseen.isEmpty) return;
    final repo = _ref.read(workCompletionRepositoryProvider);
    final batch = repo.collection.firestore.batch();
    final now = Timestamp.now();
    for (final item in unseen) {
      batch.update(repo.collection.doc(item.id), {'seenAt': now});
    }
    await batch.commit();
  }

  bool _differs(WorkCompletion? existing, CompletionEntry entry) {
    if (existing == null) return true;
    return existing.status != entry.status ||
        _blankToNull(existing.remark) != _blankToNull(entry.remark);
  }

  String? _blankToNull(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();
}
