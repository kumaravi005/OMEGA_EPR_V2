import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/notification_hook.dart';
import '../../../core/services/sequence_service.dart';
import '../../auth/application/auth_providers.dart';
import '../../student/data/payment.dart';
import '../../student/data/student_admission.dart';
import '../../student/data/student_profile.dart';
import '../data/fee_payment.dart';
import '../data/fee_payment_repository.dart';

class FeePaymentFailure implements Exception {
  const FeePaymentFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

final feePaymentControllerProvider = Provider<FeePaymentController>(
  (ref) => FeePaymentController(ref),
);

/// Admin-only (see firestore.rules) - the only write path for [FeePayment].
class FeePaymentController {
  FeePaymentController(this._ref);

  final Ref _ref;

  /// Records a new payment against [admission] - the student's CURRENT
  /// active admission, never an arbitrary/superseded one (Set 19 section
  /// 24). [currentDue] is the balance due the caller already computed and
  /// displayed to admin just before this call (Set 19 section 7's
  /// "review before confirm" step) - re-checked here rather than
  /// re-fetched, matching this project's established "validate what the
  /// UI already showed" pattern rather than adding a second live read for
  /// a single-admin-institute scale where a genuine race is vanishingly
  /// unlikely (see docs/database-architecture.md).
  Future<void> recordPayment({
    required StudentProfile student,
    required StudentAdmission admission,
    required double amount,
    required DateTime paymentDate,
    required PaymentMode mode,
    String? referenceNumber,
    String? remark,
    int? installmentIndex,
    String? installmentLabel,
    required double currentDue,
  }) async {
    if (amount <= 0) {
      throw const FeePaymentFailure('Enter a payment amount greater than zero.');
    }
    if (!admission.active) {
      throw const FeePaymentFailure(
        'This admission is no longer active. Refresh and try again.',
      );
    }
    // A small tolerance for floating-point rounding, not a loophole -
    // "prefer rejecting an amount that would make total paid exceed the
    // applicable final fee" (section 8), since this project has no
    // designed advance/overpayment concept.
    if (amount - currentDue > 0.01) {
      final dueLabel = currentDue > 0 ? '₹${currentDue.toStringAsFixed(0)}' : '₹0';
      throw FeePaymentFailure(
        'This payment would exceed the outstanding balance ($dueLabel due).',
      );
    }

    final admin = _ref.read(currentUserAccountProvider).valueOrNull;
    if (admin == null) {
      throw const FeePaymentFailure('Please sign in again.');
    }

    try {
      // The counter increment is itself atomic (see SequenceService) -
      // the same "atomic counter, then a normal write" pattern already
      // used for admission numbers (Set 11), so two payments recorded at
      // nearly the same moment can never receive the same paymentNumber
      // (section 23).
      final sequenceNumber = await _ref.read(sequenceServiceProvider).next('feePayments');
      final now = DateTime.now();
      final id = await _ref.read(feePaymentRepositoryProvider).add(
        FeePayment(
          paymentId: '',
          paymentNumber: formatPaymentNumber(sequenceNumber),
          studentId: student.uid,
          admissionId: admission.admissionId,
          academicSessionId: admission.academicSessionId,
          classId: admission.classId,
          batchId: admission.batchId,
          amount: amount,
          paymentDate: paymentDate,
          mode: mode,
          referenceNumber: _blankToNull(referenceNumber),
          remark: _blankToNull(remark),
          installmentIndex: installmentIndex,
          installmentLabel: installmentLabel,
          finalFeeAtPayment: admission.finalFee,
          collectedBy: admin.uid,
          createdAt: now,
        ),
      );
      await recordFeePaymentNotification(
        _ref,
        studentUid: student.uid,
        batchId: admission.batchId,
        amount: amount,
        relatedId: id,
      );
    } catch (error) {
      if (error is FeePaymentFailure) rethrow;
      throw const FeePaymentFailure('Could not record the payment. Please try again.');
    }
  }

  /// A controlled correction, never a silent edit (Set 19 section 9): the
  /// original [existing] document's amount/mode/date/etc. never change -
  /// only `status`/`reversedBy`/`reversedAt`/`reversalReason` (see
  /// `feePaymentReversalIsValid` in firestore.rules). Admin then records a
  /// new, correct payment separately if needed.
  Future<void> reversePayment(FeePayment existing, String reason) async {
    if (existing.isReversed) {
      throw const FeePaymentFailure('This payment has already been reversed.');
    }
    if (reason.trim().isEmpty) {
      throw const FeePaymentFailure('Enter a reason for the reversal.');
    }

    final admin = _ref.read(currentUserAccountProvider).valueOrNull;
    if (admin == null) {
      throw const FeePaymentFailure('Please sign in again.');
    }

    try {
      await _ref.read(feePaymentRepositoryProvider).updateFields(
        existing.paymentId,
        {
          'status': FeePaymentRecordStatus.reversed.name,
          'reversedBy': admin.uid,
          'reversedAt': Timestamp.now(),
          'reversalReason': reason.trim(),
        },
      );
    } catch (error) {
      if (error is FeePaymentFailure) rethrow;
      throw const FeePaymentFailure('Could not reverse this payment. Please try again.');
    }
  }

  String? _blankToNull(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();
}
