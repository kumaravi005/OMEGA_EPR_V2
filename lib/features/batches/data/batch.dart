import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';

/// A named group students are admitted into (e.g. "Class 5 Morning"),
/// carrying the standard fee students in it are expected to pay before
/// any per-student discount/adjustment.
///
/// [academicSessionId]/[classId] reference the Set 9 master data
/// (`academicSessions`/`classes`) by stable id, never by display name -
/// a batch always belongs to exactly one session and one class, so
/// "Class 10 Morning" in 2026-27 and 2027-28 are two different batch
/// documents, never the same one silently reused. [boardId] is optional
/// (a board isn't required for every institute's batch structure);
/// [boardCustomText] only has meaning when the selected board's name is
/// "Others" - see docs/database-architecture.md.
///
/// [academicSessionId]/[classId] are empty strings on documents created
/// before Set 10 (they didn't exist yet) - never null, so older code
/// reading a `Batch` doesn't have to null-check them, but
/// [isLinkedToMasterData] is false for those until an admin edits the
/// batch and fills them in. Historical batches are never migrated or
/// deleted automatically.
class Batch implements FirestoreDocument {
  const Batch({
    required this.batchId,
    required this.name,
    this.batchCode,
    this.description,
    required this.academicSessionId,
    required this.classId,
    this.boardId,
    this.boardCustomText,
    required this.standardMonthlyFee,
    required this.standardInstallmentFee,
    required this.active,
    this.studentCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Batch.fromMap(String id, Map<String, dynamic> map) {
    return Batch(
      batchId: id,
      name: map['name'] as String,
      batchCode: map['batchCode'] as String?,
      description: map['description'] as String?,
      academicSessionId: map['academicSessionId'] as String? ?? '',
      classId: map['classId'] as String? ?? '',
      boardId: map['boardId'] as String?,
      boardCustomText: map['boardCustomText'] as String?,
      standardMonthlyFee: (map['standardMonthlyFee'] as num).toDouble(),
      standardInstallmentFee: (map['standardInstallmentFee'] as num).toDouble(),
      active: map['active'] as bool,
      studentCount: (map['studentCount'] as num?)?.toInt() ?? 0,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  final String batchId;
  final String name;
  final String? batchCode;
  final String? description;
  final String academicSessionId;
  final String classId;
  final String? boardId;
  final String? boardCustomText;
  final double standardMonthlyFee;
  final double standardInstallmentFee;
  final bool active;

  /// Denormalized, maintained by a future Student Admission set
  /// (incremented/decremented when a student is admitted to or removed
  /// from this batch) - never written to by anything in Set 10. Always
  /// `0` on a batch created here.
  final int studentCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// `false` for a batch created before Set 10, which has no
  /// session/class - the UI should call this out rather than silently
  /// showing blanks.
  bool get isLinkedToMasterData =>
      academicSessionId.isNotEmpty && classId.isNotEmpty;

  /// The standard fee for [isInstallment] (installment/course plan) or
  /// the monthly plan otherwise - the one place this lookup is
  /// implemented, so a future Student Admission screen (and the
  /// existing admission form) share it instead of duplicating the
  /// if/else. Never modified by a per-student discount - see
  /// docs/database-architecture.md's "Standard fee vs. final agreed fee".
  double standardFeeFor({required bool isInstallment}) =>
      isInstallment ? standardInstallmentFee : standardMonthlyFee;

  @override
  String get id => batchId;

  @override
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'batchCode': batchCode,
      'description': description,
      'academicSessionId': academicSessionId,
      'classId': classId,
      'boardId': boardId,
      'boardCustomText': boardCustomText,
      'standardMonthlyFee': standardMonthlyFee,
      'standardInstallmentFee': standardInstallmentFee,
      'active': active,
      'studentCount': studentCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
