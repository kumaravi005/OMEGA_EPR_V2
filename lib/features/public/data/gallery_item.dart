import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';

/// A public gallery photo. `imageUrl` is admin-pasted (Firebase Storage
/// isn't enabled on this project - see docs/firebase-setup.md); swapping
/// to a real upload picker later only touches the create/edit form.
class GalleryItem implements FirestoreDocument {
  const GalleryItem({
    required this.itemId,
    required this.imageUrl,
    required this.title,
    required this.description,
    required this.category,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GalleryItem.fromMap(String id, Map<String, dynamic> map) {
    return GalleryItem(
      itemId: id,
      imageUrl: map['imageUrl'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      category: map['category'] as String?,
      active: map['active'] as bool,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  final String itemId;
  final String imageUrl;
  final String title;
  final String? description;
  final String? category;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  String get id => itemId;

  @override
  Map<String, dynamic> toMap() {
    return {
      'imageUrl': imageUrl,
      'title': title,
      'description': description,
      'category': category,
      'active': active,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
