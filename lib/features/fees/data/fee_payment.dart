import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';
import '../../student/data/payment.dart';

/// Formats a raw sequence number into the institute's payment/receipt
/// number format - the same pure, directly-testable pattern as
/// `formatAdmissionNumber` (Set 11). Never changes after creation (Set 19
/// section 6) - nothing in this codebase ever rewrites a `paymentNumber`
/// once assigned.
String formatPaymentNumber(int sequenceNumber) =>
    'PAY${sequenceNumber.toString().padLeft(4, '0')}';

/// A payment is either [active] (counts toward total paid/balance due) or
/// [reversed] (a correction - see [FeePayment]'s class doc comment). There
/// is no third state and no way back from [reversed] to [active] - a
/// mistaken reversal is corrected by recording a new payment, not by
/// un-reversing this one.
enum FeePaymentRecordStatus {
  active,
  reversed;

  static FeePaymentRecordStatus fromValue(String value) {
    return FeePaymentRecordStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => throw ArgumentError('Unknown fee payment status: $value'),
    );
  }
}

/// One fee payment recorded by admin against a student's CURRENT
/// admission, stored at the top-level `feePayments/{paymentId}` (Set 19) -
/// see docs/database-architecture.md's "Fee Collection & Payment
/// Management (Set 19)" for the full design, and why this supersedes
/// (without deleting) the Set 3 `students/{uid}/payments` subcollection.
///
/// [studentId]/[admissionId]/[academicSessionId]/[classId]/[batchId] and
/// [finalFeeAtPayment] are all snapshotted at creation and NEVER rewritten
/// afterward, even by a reversal - "historical financial data must never
/// be rewritten by later admission/fee changes" (Set 19's own core
/// principle) and "old payment history remains attached to its original
/// admission" after a batch change. [amount]/[paymentDate]/[mode]/
/// [referenceNumber]/[remark]/[installmentIndex]/[installmentLabel] are
/// likewise fixed for the life of the document - the ONLY fields a
/// reversal (see [FeePaymentRecordStatus.reversed]) may ever change are
/// [status]/[reversedBy]/[reversedAt]/[reversalReason] (see
/// `feePaymentReversalIsValid` in firestore.rules). The document is never
/// deleted (`allow delete: if false`).
class FeePayment implements FirestoreDocument {
  const FeePayment({
    required this.paymentId,
    required this.paymentNumber,
    required this.studentId,
    required this.admissionId,
    required this.academicSessionId,
    required this.classId,
    required this.batchId,
    required this.amount,
    required this.paymentDate,
    required this.mode,
    this.referenceNumber,
    this.remark,
    this.installmentIndex,
    this.installmentLabel,
    required this.finalFeeAtPayment,
    this.status = FeePaymentRecordStatus.active,
    this.reversedBy,
    this.reversedAt,
    this.reversalReason,
    required this.collectedBy,
    required this.createdAt,
  });

  factory FeePayment.fromMap(String id, Map<String, dynamic> map) {
    return FeePayment(
      paymentId: id,
      paymentNumber: map['paymentNumber'] as String,
      studentId: map['studentId'] as String,
      admissionId: map['admissionId'] as String,
      academicSessionId: map['academicSessionId'] as String,
      classId: map['classId'] as String,
      batchId: map['batchId'] as String,
      amount: (map['amount'] as num).toDouble(),
      paymentDate: (map['paymentDate'] as Timestamp).toDate(),
      mode: PaymentMode.fromValue(map['mode'] as String),
      referenceNumber: map['referenceNumber'] as String?,
      remark: map['remark'] as String?,
      installmentIndex: (map['installmentIndex'] as num?)?.toInt(),
      installmentLabel: map['installmentLabel'] as String?,
      finalFeeAtPayment: (map['finalFeeAtPayment'] as num).toDouble(),
      status: FeePaymentRecordStatus.fromValue(map['status'] as String),
      reversedBy: map['reversedBy'] as String?,
      reversedAt: (map['reversedAt'] as Timestamp?)?.toDate(),
      reversalReason: map['reversalReason'] as String?,
      collectedBy: map['collectedBy'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  final String paymentId;
  final String paymentNumber;
  final String studentId;
  final String admissionId;
  final String academicSessionId;
  final String classId;
  final String batchId;
  final double amount;
  final DateTime paymentDate;
  final PaymentMode mode;
  final String? referenceNumber;
  final String? remark;

  /// The 0-based index into the originating admission's
  /// `installments` list this payment was explicitly allocated to, or
  /// `null` when the admin left it unallocated ("apply toward the
  /// overall outstanding balance" - Set 19 section 12). See
  /// `computeInstallmentRows` for how an unallocated payment is still
  /// reflected in the installment schedule display.
  final int? installmentIndex;

  /// The installment's own label AT THE TIME of this payment - a display
  /// snapshot, never re-resolved from the (mutable) admission later.
  final String? installmentLabel;

  /// The admission's `finalFee` at the moment this payment was recorded -
  /// an immutable snapshot for a future receipt/statement, never used for
  /// today's due calculation (which always reads the CURRENT active
  /// admission's `finalFee` directly).
  final double finalFeeAtPayment;
  final FeePaymentRecordStatus status;
  final String? reversedBy;
  final DateTime? reversedAt;
  final String? reversalReason;

  /// The admin `uid` who recorded this payment.
  final String collectedBy;
  final DateTime createdAt;

  bool get isReversed => status == FeePaymentRecordStatus.reversed;

  @override
  String get id => paymentId;

  @override
  Map<String, dynamic> toMap() {
    return {
      'paymentNumber': paymentNumber,
      'studentId': studentId,
      'admissionId': admissionId,
      'academicSessionId': academicSessionId,
      'classId': classId,
      'batchId': batchId,
      'amount': amount,
      'paymentDate': Timestamp.fromDate(paymentDate),
      'mode': mode.name,
      'referenceNumber': referenceNumber,
      'remark': remark,
      'installmentIndex': installmentIndex,
      'installmentLabel': installmentLabel,
      'finalFeeAtPayment': finalFeeAtPayment,
      'status': status.name,
      'reversedBy': reversedBy,
      'reversedAt': reversedAt == null ? null : Timestamp.fromDate(reversedAt!),
      'reversalReason': reversalReason,
      'collectedBy': collectedBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
