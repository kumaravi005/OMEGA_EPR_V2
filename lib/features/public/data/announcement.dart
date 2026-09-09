import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';

/// A short public/institute-wide announcement.
class Announcement implements FirestoreDocument {
  const Announcement({
    required this.announcementId,
    required this.title,
    required this.body,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Announcement.fromMap(String id, Map<String, dynamic> map) {
    return Announcement(
      announcementId: id,
      title: map['title'] as String,
      body: map['body'] as String,
      active: map['active'] as bool,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  final String announcementId;
  final String title;
  final String body;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  String get id => announcementId;

  @override
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'active': active,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
