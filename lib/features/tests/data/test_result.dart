import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';

/// One student's marks for one test, stored at
/// `testResults/{testId}_{studentUid}` (deterministic id - re-entering a
/// mark updates the same document instead of duplicating it).
///
/// Visibility of a result to the student it belongs to is controlled by
/// the *test's* `resultPublished` flag, not anything on this document -
/// see docs/database-architecture.md.
///
/// [isAbsent] distinguishes a student who did not attempt the test from
/// one who scored a genuine zero (Set 14 spec: "do not automatically
/// convert an empty field to 0"). When [isAbsent] is `true`,
/// [obtainedMarks] is always `null` - there is no numeric value to show,
/// not a hidden zero. A student with no [TestResult] document at all is
/// a third, distinct state: "not yet entered" (nothing has been decided
/// for them either way).
class TestResult implements FirestoreDocument {
  const TestResult({
    required this.resultId,
    required this.testId,
    required this.studentUid,
    required this.batchId,
    required this.isAbsent,
    required this.obtainedMarks,
    required this.totalMarks,
    required this.remark,
    required this.enteredBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TestResult.fromMap(String id, Map<String, dynamic> map) {
    return TestResult(
      resultId: id,
      testId: map['testId'] as String,
      studentUid: map['studentUid'] as String,
      batchId: map['batchId'] as String,
      isAbsent: map['isAbsent'] as bool? ?? false,
      obtainedMarks: (map['obtainedMarks'] as num?)?.toDouble(),
      totalMarks: (map['totalMarks'] as num).toDouble(),
      remark: map['remark'] as String?,
      enteredBy: map['enteredBy'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  final String resultId;
  final String testId;
  final String studentUid;
  final String batchId;
  final bool isAbsent;

  /// `null` when [isAbsent] is `true`, or on a legacy document that
  /// somehow lacks it - never a stand-in `0`.
  final double? obtainedMarks;
  final double totalMarks;
  final String? remark;
  final String enteredBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// `null` when there is nothing to compute a percentage from (absent,
  /// or no marks value) - callers should render that as "-"/"Absent",
  /// never as 0%.
  double? get percentage {
    final marks = obtainedMarks;
    if (isAbsent || marks == null) return null;
    if (totalMarks == 0) return 0;
    return (marks / totalMarks) * 100;
  }

  static String idFor({required String testId, required String studentUid}) =>
      '${testId}_$studentUid';

  @override
  String get id => resultId;

  @override
  Map<String, dynamic> toMap() {
    return {
      'testId': testId,
      'studentUid': studentUid,
      'batchId': batchId,
      'isAbsent': isAbsent,
      'obtainedMarks': obtainedMarks,
      'totalMarks': totalMarks,
      'remark': remark,
      'enteredBy': enteredBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
