import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';
import '../../../data/models/gender.dart';

/// Matches the batch's two configured fees exactly (see [Batch]):
/// choosing a plan is what decides whether a student's standard fee is
/// auto-populated from `standardMonthlyFee` or `standardInstallmentFee`.
enum PaymentPlan {
  monthly,
  installment;

  static PaymentPlan fromValue(String value) {
    return PaymentPlan.values.firstWhere(
      (plan) => plan.name == value,
      orElse: () => throw ArgumentError('Unknown payment plan: $value'),
    );
  }

  String get label => switch (this) {
    PaymentPlan.monthly => 'Monthly',
    PaymentPlan.installment => 'Installment',
  };
}

/// A student's stable identity + their CURRENT admission/fee snapshot,
/// keyed by the same uid as their `users` login account.
///
/// [className]/[board]/[academicSession] are display strings resolved
/// from the Set 9 master data at admission/transfer time (never
/// hand-typed by the admin - see docs/database-architecture.md); the
/// authoritative references are [classId]/[boardId]/[academicSessionId].
/// [batchId] is the primary source of truth for class/session (Set 11
/// spec) - [classId]/[academicSessionId] are always the selected batch's
/// own, never entered independently.
///
/// This document only ever reflects the student's CURRENT admission -
/// every admission (initial or a later batch transfer) is additionally
/// recorded, immutably, at `students/{uid}/admissions/{admissionId}` (see
/// [StudentAdmission]); [currentAdmissionId] points at the one this
/// document's fee/academic fields were last synced from. Historical
/// admissions are never rewritten when this document changes.
///
/// [standardFee] is a snapshot of the batch's standard fee at the time of
/// the current admission, kept only for reference/comparison. [finalFee]
/// is the figure actually agreed with the family and is what every
/// payment/due calculation uses (see docs/database-architecture.md's fee
/// model). [photoUrl] is a plain pasted external URL - Firebase Storage
/// isn't enabled on this project (Spark plan), so this follows the same
/// pattern already used for the institute logo/gallery/banners.
class StudentProfile implements FirestoreDocument {
  const StudentProfile({
    required this.uid,
    required this.accountId,
    required this.admissionNumber,
    required this.name,
    required this.fatherName,
    required this.dateOfBirth,
    required this.gender,
    this.photoUrl,
    required this.address,
    required this.className,
    required this.board,
    required this.batchId,
    required this.academicSession,
    required this.academicSessionId,
    required this.classId,
    this.boardId,
    this.boardCustomText,
    required this.primaryMobile,
    required this.secondaryMobile,
    required this.standardFee,
    required this.finalFee,
    required this.feeReason,
    required this.paymentPlan,
    required this.admissionDate,
    required this.currentAdmissionId,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudentProfile.fromMap(String id, Map<String, dynamic> map) {
    return StudentProfile(
      uid: id,
      accountId: map['accountId'] as String,
      admissionNumber: map['admissionNumber'] as String? ?? '',
      name: map['name'] as String,
      fatherName: map['fatherName'] as String,
      dateOfBirth: (map['dateOfBirth'] as Timestamp).toDate(),
      gender: Gender.fromValue(map['gender'] as String),
      photoUrl: map['photoUrl'] as String?,
      address: map['address'] as String,
      className: map['className'] as String,
      board: map['board'] as String,
      batchId: map['batchId'] as String,
      academicSession: map['academicSession'] as String,
      academicSessionId: map['academicSessionId'] as String? ?? '',
      classId: map['classId'] as String? ?? '',
      boardId: map['boardId'] as String?,
      boardCustomText: map['boardCustomText'] as String?,
      primaryMobile: map['primaryMobile'] as String,
      secondaryMobile: map['secondaryMobile'] as String?,
      standardFee: (map['standardFee'] as num).toDouble(),
      finalFee: (map['finalFee'] as num).toDouble(),
      feeReason: map['feeReason'] as String?,
      paymentPlan: PaymentPlan.fromValue(map['paymentPlan'] as String),
      admissionDate: (map['admissionDate'] as Timestamp?)?.toDate() ??
          (map['createdAt'] as Timestamp).toDate(),
      currentAdmissionId: map['currentAdmissionId'] as String? ?? '',
      active: map['active'] as bool,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  final String uid;
  final String accountId;

  /// Stable, unique, assigned once at admission - never regenerated or
  /// changed by a name/batch/board/contact change (see
  /// [formatAdmissionNumber] and `SequenceService`). Empty string on a
  /// pre-Set-11 student document.
  final String admissionNumber;
  final String name;
  final String fatherName;
  final DateTime dateOfBirth;
  final Gender gender;

  /// A pasted external image URL, or `null` if none was provided.
  final String? photoUrl;
  final String address;
  final String className;
  final String board;
  final String batchId;
  final String academicSession;

  /// Empty string on a pre-Set-11 student document (never null) - see
  /// [Batch.isLinkedToMasterData] for the identical convention.
  final String academicSessionId;
  final String classId;
  final String? boardId;
  final String? boardCustomText;
  final String primaryMobile;
  final String? secondaryMobile;
  final double standardFee;
  final double finalFee;
  final String? feeReason;
  final PaymentPlan paymentPlan;

  /// The date of the CURRENT admission (initial admission, or the most
  /// recent batch transfer) - not the account's `createdAt`, which never
  /// changes. Falls back to [createdAt] when reading a pre-Set-11 record
  /// that predates this field.
  final DateTime admissionDate;

  /// Points at the `students/{uid}/admissions/{admissionId}` document
  /// this profile's academic/fee fields were last synced from. Empty
  /// string on a pre-Set-11 student document.
  final String currentAdmissionId;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get discount => standardFee - finalFee;

  /// `false` for a student admitted before Set 11 wired session/class by
  /// id - the UI should call this out rather than silently showing
  /// blanks (see [Batch.isLinkedToMasterData]).
  bool get isLinkedToMasterData =>
      academicSessionId.isNotEmpty && classId.isNotEmpty;

  @override
  String get id => uid;

  @override
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'accountId': accountId,
      'admissionNumber': admissionNumber,
      'name': name,
      'fatherName': fatherName,
      'dateOfBirth': Timestamp.fromDate(dateOfBirth),
      'gender': gender.name,
      'photoUrl': photoUrl,
      'address': address,
      'className': className,
      'board': board,
      'batchId': batchId,
      'academicSession': academicSession,
      'academicSessionId': academicSessionId,
      'classId': classId,
      'boardId': boardId,
      'boardCustomText': boardCustomText,
      'primaryMobile': primaryMobile,
      'secondaryMobile': secondaryMobile,
      'standardFee': standardFee,
      'finalFee': finalFee,
      'feeReason': feeReason,
      'paymentPlan': paymentPlan.name,
      'admissionDate': Timestamp.fromDate(admissionDate),
      'currentAdmissionId': currentAdmissionId,
      'active': active,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
