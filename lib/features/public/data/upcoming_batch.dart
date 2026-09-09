import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';

/// A public marketing listing for a batch that's about to start -
/// distinct from `batches` (Set 3's operational fee/enrollment entity).
/// `admissionStatus` is free text ("Admission open", "Few seats left",
/// "Closed", ...) rather than a fixed enum, since the spec doesn't
/// prescribe a specific vocabulary.
class UpcomingBatch implements FirestoreDocument {
  const UpcomingBatch({
    required this.upcomingBatchId,
    required this.posterUrl,
    required this.title,
    required this.className,
    required this.board,
    required this.academicSession,
    required this.startDate,
    required this.timing,
    required this.description,
    required this.admissionStatus,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UpcomingBatch.fromMap(String id, Map<String, dynamic> map) {
    return UpcomingBatch(
      upcomingBatchId: id,
      posterUrl: map['posterUrl'] as String?,
      title: map['title'] as String,
      className: map['className'] as String,
      board: map['board'] as String,
      academicSession: map['academicSession'] as String,
      startDate: (map['startDate'] as Timestamp).toDate(),
      timing: map['timing'] as String,
      description: map['description'] as String?,
      admissionStatus: map['admissionStatus'] as String,
      active: map['active'] as bool,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  final String upcomingBatchId;
  final String? posterUrl;
  final String title;
  final String className;
  final String board;
  final String academicSession;
  final DateTime startDate;
  final String timing;
  final String? description;
  final String admissionStatus;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  String get id => upcomingBatchId;

  @override
  Map<String, dynamic> toMap() {
    return {
      'posterUrl': posterUrl,
      'title': title,
      'className': className,
      'board': board,
      'academicSession': academicSession,
      'startDate': Timestamp.fromDate(startDate),
      'timing': timing,
      'description': description,
      'admissionStatus': admissionStatus,
      'active': active,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
