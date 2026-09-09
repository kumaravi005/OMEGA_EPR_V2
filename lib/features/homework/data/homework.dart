import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';

enum CompletionStatus {
  pending,
  completed;

  static CompletionStatus fromValue(String value) {
    return CompletionStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => throw ArgumentError('Unknown completion status: $value'),
    );
  }

  String get label => this == CompletionStatus.completed ? 'Completed' : 'Pending';
}

/// One homework entry for a batch/subject - never per-student (a batch's
/// homework is shared by every student in it, same as attendance).
class Homework implements FirestoreDocument {
  const Homework({
    required this.homeworkId,
    required this.batchId,
    required this.subject,
    required this.date,
    required this.description,
    required this.dueDate,
    required this.completionStatus,
    required this.remark,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Homework.fromMap(String id, Map<String, dynamic> map) {
    return Homework(
      homeworkId: id,
      batchId: map['batchId'] as String,
      subject: map['subject'] as String,
      date: (map['date'] as Timestamp).toDate(),
      description: map['description'] as String,
      dueDate: (map['dueDate'] as Timestamp).toDate(),
      completionStatus: CompletionStatus.fromValue(map['completionStatus'] as String),
      remark: map['remark'] as String?,
      createdBy: map['createdBy'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  final String homeworkId;
  final String batchId;
  final String subject;
  final DateTime date;
  final String description;
  final DateTime dueDate;
  final CompletionStatus completionStatus;
  final String? remark;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  String get id => homeworkId;

  @override
  Map<String, dynamic> toMap() {
    return {
      'batchId': batchId,
      'subject': subject,
      'date': Timestamp.fromDate(date),
      'description': description,
      'dueDate': Timestamp.fromDate(dueDate),
      'completionStatus': completionStatus.name,
      'remark': remark,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
