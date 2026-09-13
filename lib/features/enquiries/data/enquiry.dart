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

/// A visitor's stated intent (Set 18 section 15) - one collection, one
/// extensible field, not two unrelated database systems for "wants
/// admission info" vs "wants a callback". Defaults to [admission] when
/// absent (every pre-Set-18 `enquiries` document was, by construction,
/// an admission enquiry - the separate `callbackRequests` collection
/// held callback requests instead, and is untouched by this enum).
enum EnquiryType {
  admission,
  callback;

  static EnquiryType fromValue(String? value) {
    if (value == null) return EnquiryType.admission;
    return EnquiryType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => EnquiryType.admission,
    );
  }

  String get label =>
      this == EnquiryType.admission ? 'Admission enquiry' : 'Callback request';
}

/// A public admission enquiry or callback request - submitted by an
/// unauthenticated visitor (see firestore.rules: `create` needs no
/// sign-in, just a well-formed payload), managed by admin afterwards.
///
/// [classId]/[boardId] (Set 18) reference the Set 9 Class/Board master
/// data - required for [EnquiryType.admission], always `null` for
/// [EnquiryType.callback] (a callback request is intentionally
/// lighter-weight, see [EnquiryController.submitCallbackRequest]).
/// [className]/[board] alongside them are resolved display-name
/// snapshots (the same "id + display name" convention used everywhere
/// else in this project), never hand-typed free text going forward - a
/// pre-Set-18 document may still have free-text values here with no
/// matching [classId]/[boardId], which is tolerated on read (both are
/// nullable) rather than migrated. [boardCustomText] is set only when
/// the selected board is "Others".
class Enquiry implements FirestoreDocument {
  const Enquiry({
    required this.enquiryId,
    required this.name,
    required this.guardianName,
    required this.enquiryType,
    required this.classId,
    required this.className,
    required this.boardId,
    required this.board,
    required this.boardCustomText,
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
      enquiryType: EnquiryType.fromValue(map['enquiryType'] as String?),
      classId: map['classId'] as String?,
      className: map['className'] as String?,
      boardId: map['boardId'] as String?,
      board: map['board'] as String?,
      boardCustomText: map['boardCustomText'] as String?,
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
  final EnquiryType enquiryType;
  final String? classId;
  final String? className;
  final String? boardId;
  final String? board;
  final String? boardCustomText;
  final String primaryPhone;
  final String? secondaryPhone;
  final String? message;
  final EnquiryStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// The board name to display - the custom text when "Others" was
  /// picked, otherwise the resolved board name, otherwise nothing.
  String? get boardDisplay =>
      (boardCustomText != null && boardCustomText!.isNotEmpty) ? boardCustomText : board;

  @override
  String get id => enquiryId;

  @override
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'guardianName': guardianName,
      'enquiryType': enquiryType.name,
      'classId': classId,
      'className': className,
      'boardId': boardId,
      'board': board,
      'boardCustomText': boardCustomText,
      'primaryPhone': primaryPhone,
      'secondaryPhone': secondaryPhone,
      'message': message,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
