import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';
import '../../../data/models/gender.dart';

/// One (class, subject) pair a teacher teaches. A teacher may have many of
/// these - e.g. Class 5 -> Science and Class 7 -> Hindi are two separate
/// assignments for the same teacher.
class ClassSubjectAssignment {
  const ClassSubjectAssignment({required this.className, required this.subject});

  factory ClassSubjectAssignment.fromMap(Map<String, dynamic> map) {
    return ClassSubjectAssignment(className: map['className'] as String, subject: map['subject'] as String);
  }

  final String className;
  final String subject;

  Map<String, dynamic> toMap() => {'className': className, 'subject': subject};
}

/// A teacher's profile record, keyed by the same uid as their `users`
/// login account (see docs/database-architecture.md). Photo is
/// deliberately not modelled yet - Firebase Storage isn't enabled on this
/// project (see docs/firebase-setup.md); adding it later is an isolated
/// change.
class TeacherProfile implements FirestoreDocument {
  const TeacherProfile({
    required this.uid,
    required this.accountId,
    required this.name,
    required this.dateOfBirth,
    required this.gender,
    required this.qualification,
    required this.address,
    required this.primaryMobile,
    required this.secondaryMobile,
    required this.assignments,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TeacherProfile.fromMap(String id, Map<String, dynamic> map) {
    final assignmentMaps = (map['assignments'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    return TeacherProfile(
      uid: id,
      accountId: map['accountId'] as String,
      name: map['name'] as String,
      dateOfBirth: (map['dateOfBirth'] as Timestamp).toDate(),
      gender: Gender.fromValue(map['gender'] as String),
      qualification: map['qualification'] as String,
      address: map['address'] as String,
      primaryMobile: map['primaryMobile'] as String,
      secondaryMobile: map['secondaryMobile'] as String?,
      assignments: assignmentMaps.map(ClassSubjectAssignment.fromMap).toList(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  final String uid;
  final String accountId;
  final String name;
  final DateTime dateOfBirth;
  final Gender gender;
  final String qualification;
  final String address;
  final String primaryMobile;
  final String? secondaryMobile;
  final List<ClassSubjectAssignment> assignments;
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
      'qualification': qualification,
      'address': address,
      'primaryMobile': primaryMobile,
      'secondaryMobile': secondaryMobile,
      'assignments': assignments.map((a) => a.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
