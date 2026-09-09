import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';

enum EnquiryStatus {
  newEnquiry,
  contacted,
  followUp,
  admissionDone,
  notInterested;

  static EnquiryStatus fromValue(String value) {
    return EnquiryStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => throw ArgumentError('Unknown enquiry status: $value'),
    );
  }

  String get label => switch (this) {
    EnquiryStatus.newEnquiry => 'New',
    EnquiryStatus.contacted => 'Contacted',
    EnquiryStatus.followUp => 'Follow-up',
    EnquiryStatus.admissionDone => 'Admission Done',
    EnquiryStatus.notInterested => 'Not Interested',
  };
}

/// A public admission enquiry - submitted by an unauthenticated visitor
/// (see firestore.rules: `create` needs no sign-in, just a well-formed
/// payload), managed by admin afterwards.
class Enquiry implements FirestoreDocument {
  const Enquiry({
    required this.enquiryId,
    required this.name,
    required this.guardianName,
    required this.className,
    required this.board,
    required this.primaryPhone,
    required this.secondaryPhone,
    required this.message,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Enquiry.fromMap(String id, Map<String, dynamic> map) {
    return Enquiry(
      enquiryId: id,
      name: map['name'] as String,
      guardianName: map['guardianName'] as String?,
      className: map['className'] as String?,
      board: map['board'] as String?,
      primaryPhone: map['primaryPhone'] as String,
      secondaryPhone: map['secondaryPhone'] as String?,
      message: map['message'] as String?,
      status: EnquiryStatus.fromValue(map['status'] as String),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  final String enquiryId;
  final String name;
  final String? guardianName;
  final String? className;
  final String? board;
  final String primaryPhone;
  final String? secondaryPhone;
  final String? message;
  final EnquiryStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  String get id => enquiryId;

  @override
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'guardianName': guardianName,
      'className': className,
      'board': board,
      'primaryPhone': primaryPhone,
      'secondaryPhone': secondaryPhone,
      'message': message,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
