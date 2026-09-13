import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';

/// Homework and assignments are the same underlying academic-work
/// concept with a type label (Set 16 spec: "use one reusable underlying
/// academic-work model where practical, with a type field... do not
/// create two completely duplicated database structures") - replacing
/// the separate `homework`/`assignments` collections Set 4 built before
/// this project had a subject/session/class master data layer.
enum AcademicWorkType {
  homework,
  assignment;

  static AcademicWorkType fromValue(String value) {
    return AcademicWorkType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => throw ArgumentError('Unknown academic work type: $value'),
    );
  }

  String get label =>
      this == AcademicWorkType.homework ? 'Homework' : 'Assignment';
}

/// A simple three-state lifecycle (Set 16 spec) - deliberately not more
/// than this ("do not over-engineer the status system").
enum AcademicWorkStatus {
  draft,
  published,
  closed;

  static AcademicWorkStatus fromValue(String value) {
    return AcademicWorkStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () =>
          throw ArgumentError('Unknown academic work status: $value'),
    );
  }

  String get label => switch (this) {
    AcademicWorkStatus.draft => 'Draft',
    AcademicWorkStatus.published => 'Published',
    AcademicWorkStatus.closed => 'Closed',
  };
}

/// One piece of homework or an assignment, shared by every student in a
/// batch - never one document per student (Set 16 spec: "do not create
/// a separate homework document for every student"; a student's own
/// visibility is derived from their current `batchId`, not from a
/// per-student record - see `studentVisibleAcademicWorkProvider`).
///
/// [academicSessionId]/[classId]/[batchId]/[subjectId] are the batch's
/// own references, snapshotted at creation time and immutable afterward
/// (see `firestore.rules`' `academicWorkUpdateIsValid`) - the same
/// historical-integrity snapshot philosophy already established for
/// Attendance (Set 13), Tests (Set 14) and Results (Set 15): a later
/// batch/class/subject configuration change, or a student moving
/// batches, must never retroactively change which session/class/batch/
/// subject a past homework/assignment is reported under. [subject] is
/// the resolved display name (kept for simple display, exactly like
/// `TestDefinition.subject`), while [subjectId] is the authoritative
/// reference.
class AcademicWork implements FirestoreDocument {
  const AcademicWork({
    required this.workId,
    required this.type,
    required this.academicSessionId,
    required this.classId,
    required this.batchId,
    required this.subjectId,
    required this.subject,
    required this.title,
    this.description,
    required this.assignedDate,
    required this.dueDate,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AcademicWork.fromMap(String id, Map<String, dynamic> map) {
    return AcademicWork(
      workId: id,
      type: AcademicWorkType.fromValue(map['type'] as String),
      academicSessionId: map['academicSessionId'] as String,
      classId: map['classId'] as String,
      batchId: map['batchId'] as String,
      subjectId: map['subjectId'] as String,
      subject: map['subject'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      assignedDate: (map['assignedDate'] as Timestamp).toDate(),
      dueDate: (map['dueDate'] as Timestamp).toDate(),
      status: AcademicWorkStatus.fromValue(map['status'] as String),
      createdBy: map['createdBy'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  final String workId;
  final AcademicWorkType type;
  final String academicSessionId;
  final String classId;
  final String batchId;
  final String subjectId;
  final String subject;
  final String title;
  final String? description;
  final DateTime assignedDate;
  final DateTime dueDate;
  final AcademicWorkStatus status;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Calculated on demand from the current date and [dueDate] - never a
  /// stored flag (Set 16 spec: "do not let an outdated stored flag
  /// become incorrect"). Only a still-[AcademicWorkStatus.published]
  /// item can be overdue - a draft isn't visible/active yet, and a
  /// closed item is simply closed, not "overdue".
  bool isOverdue(DateTime now) =>
      status == AcademicWorkStatus.published && now.isAfter(dueDate);

  @override
  String get id => workId;

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'academicSessionId': academicSessionId,
      'classId': classId,
      'batchId': batchId,
      'subjectId': subjectId,
      'subject': subject,
      'title': title,
      'description': description,
      'assignedDate': Timestamp.fromDate(assignedDate),
      'dueDate': Timestamp.fromDate(dueDate),
      'status': status.name,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
