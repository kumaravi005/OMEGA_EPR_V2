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

/// A student's admission + fee record, keyed by the same uid as their
/// `users` login account. Photo is deliberately not modelled yet -
/// Firebase Storage isn't enabled on this project (see
/// docs/firebase-setup.md); adding it later is an isolated change.
///
/// Fee fields: [standardFee] is a snapshot of the batch's standard fee at
/// admission time, kept only for reference/comparison. [finalFee] is the
/// figure actually agreed with the family and is what every payment/due
/// calculation uses (see docs/database-architecture.md's fee model).
class StudentProfile implements FirestoreDocument {
  const StudentProfile({
    required this.uid,
    required this.accountId,
    required this.name,
    required this.fatherName,
    required this.dateOfBirth,
    required this.gender,
    required this.address,
    required this.className,
    required this.board,
    required this.batchId,
    required this.academicSession,
    required this.primaryMobile,
    required this.secondaryMobile,
    required this.standardFee,
    required this.finalFee,
    required this.feeReason,
    required this.paymentPlan,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudentProfile.fromMap(String id, Map<String, dynamic> map) {
    return StudentProfile(
      uid: id,
      accountId: map['accountId'] as String,
      name: map['name'] as String,
      fatherName: map['fatherName'] as String,
      dateOfBirth: (map['dateOfBirth'] as Timestamp).toDate(),
      gender: Gender.fromValue(map['gender'] as String),
      address: map['address'] as String,
      className: map['className'] as String,
      board: map['board'] as String,
      batchId: map['batchId'] as String,
      academicSession: map['academicSession'] as String,
      primaryMobile: map['primaryMobile'] as String,
      secondaryMobile: map['secondaryMobile'] as String?,
      standardFee: (map['standardFee'] as num).toDouble(),
      finalFee: (map['finalFee'] as num).toDouble(),
      feeReason: map['feeReason'] as String?,
      paymentPlan: PaymentPlan.fromValue(map['paymentPlan'] as String),
      active: map['active'] as bool,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  final String uid;
  final String accountId;
  final String name;
  final String fatherName;
  final DateTime dateOfBirth;
  final Gender gender;
  final String address;
  final String className;
  final String board;
  final String batchId;
  final String academicSession;
  final String primaryMobile;
  final String? secondaryMobile;
  final double standardFee;
  final double finalFee;
  final String? feeReason;
  final PaymentPlan paymentPlan;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get discount => standardFee - finalFee;

  @override
  String get id => uid;

  @override
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'accountId': accountId,
      'name': name,
      'fatherName': fatherName,
      'dateOfBirth': Timestamp.fromDate(dateOfBirth),
      'gender': gender.name,
      'address': address,
      'className': className,
      'board': board,
      'batchId': batchId,
      'academicSession': academicSession,
      'primaryMobile': primaryMobile,
      'secondaryMobile': secondaryMobile,
      'standardFee': standardFee,
      'finalFee': finalFee,
      'feeReason': feeReason,
      'paymentPlan': paymentPlan.name,
      'active': active,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
