import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';

/// An academic year/term (e.g. "2026-27"). Exactly one session is ever
/// `isActive` at a time - enforced client-side by
/// `AcademicSessionController.setActiveSession` (an atomic Firestore
/// `WriteBatch` that flips the previous active session off and the new
/// one on in a single commit), not by a Firestore rule - Firestore rules
/// can't inspect *other* documents in a collection to enforce "no more
/// than one" as a security invariant, and getting this wrong has no
/// security consequence (worst case is a display inconsistency, not
/// unauthorized access), so client-side atomicity is enough here.
///
/// Future student/batch/fee/attendance/test/result records are expected
/// to carry a `sessionId` referencing this document's id - not this
/// set's job to wire (see docs/architecture.md's Set 9 section for the
/// scope boundary), but the id is stable and ready to be referenced.
class AcademicSession implements FirestoreDocument {
  const AcademicSession({
    required this.sessionId,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AcademicSession.fromMap(String id, Map<String, dynamic> map) {
    return AcademicSession(
      sessionId: id,
      name: map['name'] as String,
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      isActive: map['isActive'] as bool,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  final String sessionId;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  String get id => sessionId;

  @override
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
