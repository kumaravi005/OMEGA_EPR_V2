import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';

/// One student's marks for one test, stored at
/// `testResults/{testId}_{studentUid}` (deterministic id - re-entering a
/// mark updates the same document instead of duplicating it).
///
/// Visibility of a result to the student it belongs to is controlled by
/// the *test's* `resultPublished` flag, not anything on this document -
/// see docs/database-architecture.md.
class TestResult implements FirestoreDocument {
  const TestResult({
    required this.resultId,
    required this.testId,
    required this.studentUid,
    required this.batchId,
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
      obtainedMarks: (map['obtainedMarks'] as num).toDouble(),
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
  final double obtainedMarks;
  final double totalMarks;
  final String? remark;
  final String enteredBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get percentage =>
      totalMarks == 0 ? 0 : (obtainedMarks / totalMarks) * 100;

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
      'obtainedMarks': obtainedMarks,
      'totalMarks': totalMarks,
      'remark': remark,
      'enteredBy': enteredBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
