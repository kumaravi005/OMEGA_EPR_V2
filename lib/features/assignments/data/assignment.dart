import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';

enum AssignmentStatus {
  active,
  closed;

  static AssignmentStatus fromValue(String value) {
    return AssignmentStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => throw ArgumentError('Unknown assignment status: $value'),
    );
  }

  String get label => this == AssignmentStatus.active ? 'Active' : 'Closed';
}

/// One assignment for a batch/subject - shared by every student in that
/// batch, same as homework.
class Assignment implements FirestoreDocument {
  const Assignment({
    required this.assignmentId,
    required this.batchId,
    required this.subject,
    required this.title,
    required this.description,
    required this.assignedDate,
    required this.dueDate,
    required this.status,
    required this.teacherRemark,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Assignment.fromMap(String id, Map<String, dynamic> map) {
    return Assignment(
      assignmentId: id,
      batchId: map['batchId'] as String,
      subject: map['subject'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      assignedDate: (map['assignedDate'] as Timestamp).toDate(),
      dueDate: (map['dueDate'] as Timestamp).toDate(),
      status: AssignmentStatus.fromValue(map['status'] as String),
      teacherRemark: map['teacherRemark'] as String?,
      createdBy: map['createdBy'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  final String assignmentId;
  final String batchId;
  final String subject;
  final String title;
  final String description;
  final DateTime assignedDate;
  final DateTime dueDate;
  final AssignmentStatus status;
  final String? teacherRemark;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  String get id => assignmentId;

  @override
  Map<String, dynamic> toMap() {
    return {
      'batchId': batchId,
      'subject': subject,
      'title': title,
      'description': description,
      'assignedDate': Timestamp.fromDate(assignedDate),
      'dueDate': Timestamp.fromDate(dueDate),
      'status': status.name,
      'teacherRemark': teacherRemark,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
