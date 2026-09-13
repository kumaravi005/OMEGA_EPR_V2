import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';

/// The occasion/category of a test (Set 14 spec) - a controlled but
/// extensible vocabulary, not free text: [other] plus
/// [TestDefinition.otherTestTypeLabel] is the escape hatch for whatever
/// isn't in this list yet, exactly like Board's "Others" + custom text
/// (Set 9). Replaces the earlier objective/subjective/mixed distinction
/// (Set 4), which named the QUESTION FORMAT rather than the occasion -
/// a pre-Set-14 test's stored value is migrated on read (see
/// [TestDefinition.fromMap]) rather than left to crash.
enum TestType {
  unitTest,
  monthlyTest,
  weeklyTest,
  halfYearly,
  finalTest,
  other;

  static TestType fromValue(String value) {
    return TestType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => throw ArgumentError('Unknown test type: $value'),
    );
  }

  String get label => switch (this) {
    TestType.unitTest => 'Unit Test',
    TestType.monthlyTest => 'Monthly Test',
    TestType.weeklyTest => 'Weekly Test',
    TestType.halfYearly => 'Half-Yearly',
    TestType.finalTest => 'Final',
    TestType.other => 'Other',
  };
}

/// An offline test's metadata - marks are entered afterwards, per
/// student, in the separate `testResults` collection (see [TestResult]).
/// There is no online exam engine here; `date` is just when the test was
/// conducted on paper.
///
/// [academicSessionId]/[classId]/[subjectId] reference the Set 9/10
/// master data by stable id (never free text) - all three are a
/// **snapshot** of the selected batch/subject at creation time, not a
/// live join, matching the same rationale Set 13 established for
/// attendance: a later edit to the batch's own session/class assignment
/// must never retroactively change which session/class a past test is
/// reported under. [subject] stays as a resolved display name (like
/// `StudentProfile.className`/`.board` since Set 11) so existing
/// consumers (the student results screen, the test-result export
/// screen) keep reading a plain string. All three are `''` on a test
/// created before Set 14.
///
/// [active] follows the same active/inactive convention as
/// Batch/Teacher/Student - "prefer deactivation over destructive
/// deletion" - rather than a bespoke draft/published/closed lifecycle;
/// combined with [resultPublished] this already distinguishes "still
/// being marked" (active, not published) from "finalized" (published)
/// from "archived" (inactive), without a third status field.
class TestDefinition implements FirestoreDocument {
  const TestDefinition({
    required this.testId,
    required this.batchId,
    required this.academicSessionId,
    required this.classId,
    required this.subjectId,
    required this.subject,
    required this.title,
    required this.chapterTopic,
    required this.date,
    required this.totalMarks,
    required this.testType,
    this.otherTestTypeLabel,
    required this.description,
    required this.active,
    required this.resultPublished,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TestDefinition.fromMap(String id, Map<String, dynamic> map) {
    final rawType = map['testType'] as String;
    final isKnownType = TestType.values.any((type) => type.name == rawType);
    return TestDefinition(
      testId: id,
      batchId: map['batchId'] as String,
      academicSessionId: map['academicSessionId'] as String? ?? '',
      classId: map['classId'] as String? ?? '',
      subjectId: map['subjectId'] as String? ?? '',
      subject: map['subject'] as String,
      title: map['title'] as String,
      chapterTopic: map['chapterTopic'] as String,
      date: (map['date'] as Timestamp).toDate(),
      totalMarks: (map['totalMarks'] as num).toDouble(),
      testType: isKnownType ? TestType.fromValue(rawType) : TestType.other,
      otherTestTypeLabel:
          map['otherTestTypeLabel'] as String? ??
          (isKnownType ? null : _capitalize(rawType)),
      description: map['description'] as String?,
      active: map['active'] as bool? ?? true,
      resultPublished: map['resultPublished'] as bool,
      createdBy: map['createdBy'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  static String _capitalize(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

  final String testId;
  final String batchId;
  final String academicSessionId;
  final String classId;
  final String subjectId;
  final String subject;
  final String title;
  final String chapterTopic;
  final DateTime date;
  final double totalMarks;
  final TestType testType;

  /// The actual label when [testType] is [TestType.other] - also used to
  /// preserve a pre-Set-14 test's original objective/subjective/mixed
  /// value for display after migration (see [fromMap]).
  final String? otherTestTypeLabel;
  final String? description;
  final bool active;
  final bool resultPublished;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// `false` for a test created before Set 14, which has no
  /// session/class/subject reference - the UI should call this out
  /// rather than silently showing blanks (see `Batch.isLinkedToMasterData`).
  bool get isLinkedToMasterData =>
      academicSessionId.isNotEmpty && classId.isNotEmpty && subjectId.isNotEmpty;

  @override
  String get id => testId;

  @override
  Map<String, dynamic> toMap() {
    return {
      'batchId': batchId,
      'academicSessionId': academicSessionId,
      'classId': classId,
      'subjectId': subjectId,
      'subject': subject,
      'title': title,
      'chapterTopic': chapterTopic,
      'date': Timestamp.fromDate(date),
      'totalMarks': totalMarks,
      'testType': testType.name,
      'otherTestTypeLabel': otherTestTypeLabel,
      'description': description,
      'active': active,
      'resultPublished': resultPublished,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
