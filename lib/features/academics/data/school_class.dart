import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';

/// One entry in the class master (e.g. "Class 9"). Named `SchoolClass`,
/// not `Class`, to avoid colliding with Dart's own `class` keyword.
///
/// [subjectIds] is the class-subject applicability link: which
/// [Subject] documents (by stable id, never by display name) apply to
/// this class. Stored here rather than as a separate join collection -
/// the only lookup direction any future module needs is "which subjects
/// does this class offer", so a field on the class is simpler and just
/// as centralized as a join table would be at this project's scale.
class SchoolClass implements FirestoreDocument {
  const SchoolClass({
    required this.classId,
    required this.name,
    required this.sortOrder,
    required this.active,
    required this.subjectIds,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SchoolClass.fromMap(String id, Map<String, dynamic> map) {
    return SchoolClass(
      classId: id,
      name: map['name'] as String,
      sortOrder: (map['sortOrder'] as num).toInt(),
      active: map['active'] as bool,
      subjectIds: List<String>.from(map['subjectIds'] as List? ?? const []),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  final String classId;
  final String name;
  final int sortOrder;
  final bool active;
  final List<String> subjectIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  String get id => classId;

  @override
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'sortOrder': sortOrder,
      'active': active,
      'subjectIds': subjectIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
