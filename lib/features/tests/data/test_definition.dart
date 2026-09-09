import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';

enum TestType {
  objective,
  subjective,
  mixed;

  static TestType fromValue(String value) {
    return TestType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => throw ArgumentError('Unknown test type: $value'),
    );
  }

  String get label => switch (this) {
    TestType.objective => 'Objective',
    TestType.subjective => 'Subjective',
    TestType.mixed => 'Mixed',
  };
}

/// An offline test's metadata - marks are entered afterwards, per
/// student, in the separate `testResults` collection (see [TestResult]).
/// There is no online exam engine here; `date` is just when the test was
/// conducted on paper.
class TestDefinition implements FirestoreDocument {
  const TestDefinition({
    required this.testId,
    required this.batchId,
    required this.subject,
    required this.title,
    required this.chapterTopic,
    required this.date,
    required this.totalMarks,
    required this.testType,
    required this.description,
    required this.resultPublished,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TestDefinition.fromMap(String id, Map<String, dynamic> map) {
    return TestDefinition(
      testId: id,
      batchId: map['batchId'] as String,
      subject: map['subject'] as String,
      title: map['title'] as String,
      chapterTopic: map['chapterTopic'] as String,
      date: (map['date'] as Timestamp).toDate(),
      totalMarks: (map['totalMarks'] as num).toDouble(),
      testType: TestType.fromValue(map['testType'] as String),
      description: map['description'] as String?,
      resultPublished: map['resultPublished'] as bool,
      createdBy: map['createdBy'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  final String testId;
  final String batchId;
  final String subject;
  final String title;
  final String chapterTopic;
  final DateTime date;
  final double totalMarks;
  final TestType testType;
  final String? description;
  final bool resultPublished;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  String get id => testId;

  @override
  Map<String, dynamic> toMap() {
    return {
      'batchId': batchId,
      'subject': subject,
      'title': title,
      'chapterTopic': chapterTopic,
      'date': Timestamp.fromDate(date),
      'totalMarks': totalMarks,
      'testType': testType.name,
      'description': description,
      'resultPublished': resultPublished,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
