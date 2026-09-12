import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';
import '../../../data/models/gender.dart';

/// De-duplicates a list of subject ids while preserving first-occurrence
/// order - used by `TeacherFormController` so "duplicate subjects cannot
/// be assigned to one teacher" holds regardless of how the ids reached
/// it (a `Set`-backed picker already prevents this in the UI, but the
/// controller normalizes independently rather than trusting the caller).
List<String> dedupeSubjectIds(List<String> subjectIds) {
  final seen = <String>{};
  final result = <String>[];
  for (final id in subjectIds) {
    if (seen.add(id)) result.add(id);
  }
  return result;
}

/// A teacher's profile record, keyed by the same uid as their `users`
/// login account (see docs/database-architecture.md).
///
/// [subjectIds] references the Set 9 subject master by stable id (never
/// a free-text/duplicated subject name) - a teacher's TEACHING CAPABILITY,
/// independent of any specific class or batch. A teacher may be capable
/// of teaching the same subject across multiple classes, and may teach
/// more than one subject - this is a flat multi-select, not a
/// one-subject-per-teacher or one-(class,subject)-pair structure. It does
/// NOT assign a teacher to a batch/class - that cross-reference is
/// explicitly future work (Set 12 spec), and nothing here prevents it.
///
/// [photoUrl] is a plain pasted external image URL - the same pattern
/// already used for student photos (and the institute logo/gallery/
/// banners): Firebase Storage isn't enabled on this project (Spark
/// plan), so this is not a Storage upload.
class TeacherProfile implements FirestoreDocument {
  const TeacherProfile({
    required this.uid,
    required this.accountId,
    required this.name,
    required this.dateOfBirth,
    required this.gender,
    this.photoUrl,
    required this.qualification,
    required this.address,
    required this.primaryMobile,
    required this.secondaryMobile,
    required this.subjectIds,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TeacherProfile.fromMap(String id, Map<String, dynamic> map) {
    return TeacherProfile(
      uid: id,
      accountId: map['accountId'] as String,
      name: map['name'] as String,
      dateOfBirth: (map['dateOfBirth'] as Timestamp).toDate(),
      gender: Gender.fromValue(map['gender'] as String),
      photoUrl: map['photoUrl'] as String?,
      qualification: map['qualification'] as String,
      address: map['address'] as String,
      primaryMobile: map['primaryMobile'] as String,
      secondaryMobile: map['secondaryMobile'] as String?,
      subjectIds: List<String>.from(map['subjectIds'] as List? ?? const []),
      // Pre-Set-12 teacher documents predate the active/inactive concept -
      // treat them as active rather than silently hiding an existing
      // teacher from every active-only picker.
      active: map['active'] as bool? ?? true,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  final String uid;
  final String accountId;
  final String name;
  final DateTime dateOfBirth;
  final Gender gender;
  final String? photoUrl;
  final String qualification;
  final String address;
  final String primaryMobile;
  final String? secondaryMobile;
  final List<String> subjectIds;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  String get id => uid;

  @override
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'accountId': accountId,
      'name': name,
      'dateOfBirth': Timestamp.fromDate(dateOfBirth),
      'gender': gender.name,
      'photoUrl': photoUrl,
      'qualification': qualification,
      'address': address,
      'primaryMobile': primaryMobile,
      'secondaryMobile': secondaryMobile,
      'subjectIds': subjectIds,
      'active': active,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
