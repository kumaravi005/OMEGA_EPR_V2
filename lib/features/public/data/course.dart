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
    required this.trackTag,
    required this.subjectChips,
    required this.syllabusUrl,
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
      trackTag: map['trackTag'] as String?,
      subjectChips:
          (map['subjectChips'] as List<dynamic>?)?.cast<String>() ?? const [],
      syllabusUrl: map['syllabusUrl'] as String?,
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

  /// Free-text badge shown on the course card (e.g. "Foundation",
  /// "Competitive") - admin-entered, not a fixed enum, same reasoning as
  /// [UpcomingBatch.admissionStatus].
  final String? trackTag;

  /// Short subject labels shown as chips on the course card (e.g.
  /// "Science", "Maths"). Empty list is the common case for a course
  /// that hasn't been given any yet - the card simply omits the chip row.
  final List<String> subjectChips;

  /// Optional external link for the card's "View syllabus" action.
  final String? syllabusUrl;
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
      'trackTag': trackTag,
      'subjectChips': subjectChips,
      'syllabusUrl': syllabusUrl,
      'active': active,
      'sortOrder': sortOrder,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
