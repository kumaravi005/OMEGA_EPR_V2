import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';

/// The single institute-profile document (`institutes/main`), powering
/// the public site's branding/about/contact sections and (Set 9) reused
/// as the central institute-configuration record every future
/// screen/report should read instead of hard-coding institute details.
/// There is exactly one of these - not a managed collection of many
/// institutes.
class InstituteProfile implements FirestoreDocument {
  const InstituteProfile({
    required this.name,
    required this.tagline,
    required this.about,
    required this.logoUrl,
    required this.contactPhone,
    required this.secondaryPhone,
    required this.contactEmail,
    required this.address,
    required this.website,
    required this.updatedAt,
  });

  factory InstituteProfile.fromMap(String id, Map<String, dynamic> map) {
    return InstituteProfile(
      name: map['name'] as String,
      tagline: map['tagline'] as String?,
      about: map['about'] as String?,
      logoUrl: map['logoUrl'] as String?,
      contactPhone: map['contactPhone'] as String?,
      secondaryPhone: map['secondaryPhone'] as String?,
      contactEmail: map['contactEmail'] as String?,
      address: map['address'] as String?,
      website: map['website'] as String?,
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  static const documentId = 'main';

  final String name;
  final String? tagline;
  final String? about;

  /// A pasted image URL, same as every other image field in this project -
  /// Storage isn't enabled (see docs/firebase-setup.md).
  final String? logoUrl;
  final String? contactPhone;
  final String? secondaryPhone;
  final String? contactEmail;
  final String? address;
  final String? website;
  final DateTime updatedAt;

  @override
  String get id => documentId;

  @override
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'tagline': tagline,
      'about': about,
      'logoUrl': logoUrl,
      'contactPhone': contactPhone,
      'secondaryPhone': secondaryPhone,
      'contactEmail': contactEmail,
      'address': address,
      'website': website,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
