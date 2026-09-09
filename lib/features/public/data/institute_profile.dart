import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';

/// The single institute-profile document (`institutes/main`), powering
/// the public site's branding/about/contact sections. There is exactly
/// one of these - not a managed collection of many institutes.
class InstituteProfile implements FirestoreDocument {
  const InstituteProfile({
    required this.name,
    required this.tagline,
    required this.about,
    required this.contactPhone,
    required this.contactEmail,
    required this.address,
    required this.updatedAt,
  });

  factory InstituteProfile.fromMap(String id, Map<String, dynamic> map) {
    return InstituteProfile(
      name: map['name'] as String,
      tagline: map['tagline'] as String?,
      about: map['about'] as String?,
      contactPhone: map['contactPhone'] as String?,
      contactEmail: map['contactEmail'] as String?,
      address: map['address'] as String?,
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  static const documentId = 'main';

  final String name;
  final String? tagline;
  final String? about;
  final String? contactPhone;
  final String? contactEmail;
  final String? address;
  final DateTime updatedAt;

  @override
  String get id => documentId;

  @override
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'tagline': tagline,
      'about': about,
      'contactPhone': contactPhone,
      'contactEmail': contactEmail,
      'address': address,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
