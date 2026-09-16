import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';

/// A course/class-level the institute teaches, shown in the public
/// landing page's "Our courses" row. `imageUrl` is optional - admin-
/// pasted, same as every other image field in this project (Firebase
/// Storage isn't enabled - see docs/firebase-setup.md); a course with no
/// image falls back to a generic icon on the public page.
class Course implements FirestoreDocument {
  const Course({
    required this.courseId,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.active,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Course.fromMap(String id, Map<String, dynamic> map) {
    return Course(
      courseId: id,
      title: map['title'] as String,
      description: map['description'] as String?,
      imageUrl: map['imageUrl'] as String?,
      active: map['active'] as bool,
      sortOrder: (map['sortOrder'] as int?) ?? 0,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  final String courseId;
  final String title;
  final String? description;
  final String? imageUrl;
  final bool active;

  /// Admin-controlled display order on the public "Our courses" row
  /// (ascending - lower first), same pattern as [BannerItem.sortOrder].
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  String get id => courseId;

  @override
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'active': active,
      'sortOrder': sortOrder,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
