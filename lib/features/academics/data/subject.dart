import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';

/// One entry in the subject master (e.g. "Mathematics"). Which classes a
/// subject applies to is stored on [SchoolClass.subjectIds], not here -
/// see that class's doc comment for why.
class Subject implements FirestoreDocument {
  const Subject({
    required this.subjectId,
    required this.name,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Subject.fromMap(String id, Map<String, dynamic> map) {
    return Subject(
      subjectId: id,
      name: map['name'] as String,
      active: map['active'] as bool,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  final String subjectId;
  final String name;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  String get id => subjectId;

  @override
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'active': active,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
