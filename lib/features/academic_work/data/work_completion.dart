import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';

/// How far a student got with a homework/assignment, as marked by their
/// teacher (or an admin). Deliberately three values, not a grade:
/// [incomplete] means partly done and still finishable by the due date;
/// [notCompleted] means not done at all. A student with no record at all
/// is simply "not marked yet" - that is never stored.
enum WorkCompletionStatus {
  completed,
  incomplete,
  notCompleted;

  static WorkCompletionStatus fromValue(String value) {
    return WorkCompletionStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () =>
          throw ArgumentError('Unknown work completion status: $value'),
    );
  }

  String get label => switch (this) {
    WorkCompletionStatus.completed => 'Completed',
    WorkCompletionStatus.incomplete => 'Incomplete',
    WorkCompletionStatus.notCompleted => 'Not completed',
  };

  String get labelHindi => switch (this) {
    WorkCompletionStatus.completed => 'पूरा',
    WorkCompletionStatus.incomplete => 'अधूरा',
    WorkCompletionStatus.notCompleted => 'पूरा नहीं',
  };
}

/// One student's completion status for one homework/assignment, at
/// `workCompletions/{workId}_{studentUid}` - a deterministic id (same
/// pattern as `TestResult.idFor`), so re-saving updates the same record
/// instead of creating a duplicate.
///
/// Kept separate from `academicWork` on purpose: that document is shared
/// by the whole batch (Set 16), so per-student state can't live on it.
/// Kept separate from `notifications` too: those events can't be made
/// private to one student under the current rules, and a completion status
/// must never be readable by classmates.
///
/// [seenAt] is `null` until the student dismisses the in-app popup for the
/// current [status]; every re-mark resets it to `null` so the student is
/// told again.
class WorkCompletion implements FirestoreDocument {
  const WorkCompletion({
    required this.workId,
    required this.studentUid,
    required this.batchId,
    required this.status,
    this.remark,
    required this.markedBy,
    required this.markedAt,
    this.seenAt,
  });

  factory WorkCompletion.fromMap(String id, Map<String, dynamic> map) {
    return WorkCompletion(
      workId: map['workId'] as String,
      studentUid: map['studentUid'] as String,
      batchId: map['batchId'] as String,
      status: WorkCompletionStatus.fromValue(map['status'] as String),
      remark: map['remark'] as String?,
      markedBy: map['markedBy'] as String,
      markedAt: (map['markedAt'] as Timestamp).toDate(),
      seenAt: (map['seenAt'] as Timestamp?)?.toDate(),
    );
  }

  static String idFor({required String workId, required String studentUid}) =>
      '${workId}_$studentUid';

  final String workId;
  final String studentUid;
  final String batchId;
  final WorkCompletionStatus status;
  final String? remark;
  final String markedBy;
  final DateTime markedAt;
  final DateTime? seenAt;

  bool get isUnseen => seenAt == null;

  @override
  String get id => idFor(workId: workId, studentUid: studentUid);

  @override
  Map<String, dynamic> toMap() {
    return {
      'workId': workId,
      'studentUid': studentUid,
      'batchId': batchId,
      'status': status.name,
      'remark': remark,
      'markedBy': markedBy,
      'markedAt': Timestamp.fromDate(markedAt),
      'seenAt': seenAt == null ? null : Timestamp.fromDate(seenAt!),
    };
  }
}

/// Counts for one piece of work, calculated on demand from the records and
/// the roster size - never stored, so they can't drift out of date (same
/// philosophy as `AcademicWork.isOverdue`).
class WorkCompletionSummary {
  const WorkCompletionSummary({
    required this.completed,
    required this.incomplete,
    required this.notCompleted,
    required this.notMarked,
  });

  factory WorkCompletionSummary.of(
    Iterable<WorkCompletion> completions, {
    required int studentCount,
  }) {
    var completed = 0;
    var incomplete = 0;
    var notCompleted = 0;
    for (final completion in completions) {
      switch (completion.status) {
        case WorkCompletionStatus.completed:
          completed++;
        case WorkCompletionStatus.incomplete:
          incomplete++;
        case WorkCompletionStatus.notCompleted:
          notCompleted++;
      }
    }
    final marked = completed + incomplete + notCompleted;
    return WorkCompletionSummary(
      completed: completed,
      incomplete: incomplete,
      notCompleted: notCompleted,
      // A student who left the batch after being marked can leave more
      // records than the current roster - never show a negative count.
      notMarked: studentCount > marked ? studentCount - marked : 0,
    );
  }

  final int completed;
  final int incomplete;
  final int notCompleted;
  final int notMarked;

  int get total => completed + incomplete + notCompleted + notMarked;
}
