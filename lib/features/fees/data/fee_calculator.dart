import '../../batches/data/installment_schedule_item.dart';
import '../../student/data/payment.dart';
import 'fee_payment.dart';

/// Pure fee/installment math - no Firestore calls, no UI, fully unit
/// tested (matching the `result_calculator.dart`/`attendance_stats.dart`
/// "reusable calculation engine" pattern already established in this
/// project). See docs/database-architecture.md's "Fee Collection &
/// Payment Management (Set 19)" for the full design and worked examples.

/// Sum of every [FeePaymentRecordStatus.active] payment - a
/// [FeePaymentRecordStatus.reversed] one contributes nothing (Set 19
/// section 10/42: "reversed payment is excluded from net paid").
double totalActiveFeePaymentAmount(List<FeePayment> payments) => payments
    .where((payment) => payment.status == FeePaymentRecordStatus.active)
    .fold(0.0, (sum, payment) => sum + payment.amount);

/// Sum of every reversed payment - shown as its own figure (Set 19
/// section 10's "Total Reversed"), never netted against active payments
/// beyond simply not counting toward them.
double totalReversedFeePaymentAmount(List<FeePayment> payments) => payments
    .where((payment) => payment.isReversed)
    .fold(0.0, (sum, payment) => sum + payment.amount);

/// Sum of every legacy (Set 3, pre-Set-19) `students/{uid}/payments`
/// document - that collection has no reversal concept, so every legacy
/// payment counts.
double totalLegacyPaymentAmount(List<Payment> legacyPayments) =>
    legacyPayments.fold(0.0, (sum, payment) => sum + payment.amount);

/// Total paid across BOTH the new [FeePayment] ledger (active only) and
/// the legacy subcollection - the one figure every fee screen in this
/// project uses, so a student's total never silently drops just because
/// some of their history predates Set 19.
double combinedTotalPaid({
  required List<FeePayment> feePayments,
  required List<Payment> legacyPayments,
}) =>
    totalActiveFeePaymentAmount(feePayments) +
    totalLegacyPaymentAmount(legacyPayments);

/// Final Fee − valid/non-reversed payments (Set 19 section 14) - NEVER
/// the student's original standard fee. Positive means still owed,
/// negative means an overpayment/advance.
double combinedBalanceDue({
  required double finalFee,
  required List<FeePayment> feePayments,
  required List<Payment> legacyPayments,
}) =>
    finalFee -
    combinedTotalPaid(feePayments: feePayments, legacyPayments: legacyPayments);

/// Where one installment row stands right now - always derived, never
/// stored (Set 19 section 13 - `InstallmentScheduleItem.status` is
/// deliberately NOT read here; see `computeInstallmentRows`'s doc
/// comment for why).
enum InstallmentDisplayStatus {
  paid,
  partiallyPaid,
  due,
  overdue;

  String get label => switch (this) {
    InstallmentDisplayStatus.paid => 'Paid',
    InstallmentDisplayStatus.partiallyPaid => 'Partially Paid',
    InstallmentDisplayStatus.due => 'Due',
    InstallmentDisplayStatus.overdue => 'Overdue',
  };
}

class InstallmentRow {
  const InstallmentRow({
    required this.index,
    required this.item,
    required this.paidAmount,
    required this.remainingAmount,
    required this.status,
  });

  /// This installment's position in the admission's own `installments`
  /// list - what `FeePayment.installmentIndex` refers to when a payment
  /// is explicitly allocated to it.
  final int index;
  final InstallmentScheduleItem item;
  final double paidAmount;
  final double remainingAmount;
  final InstallmentDisplayStatus status;
}

/// Derives each installment's paid/remaining amount and display status
/// from the admission's schedule plus its payments - never from
/// [InstallmentScheduleItem.status], which nothing in this codebase ever
/// updates away from its default (`pending`) and which Set 19 section 13
/// explicitly asks NOT to rely on ("do not store a fragile permanent
/// installment status if it can be derived").
///
/// A payment explicitly allocated to an installment
/// (`FeePayment.installmentIndex`) reduces that installment's balance
/// first; every unallocated payment is then applied as one pooled amount
/// across the remaining installments in DUE-DATE order (earliest first) -
/// "if no installment is selected, apply the payment toward the overall
/// outstanding balance" (section 12), interpreted so the schedule display
/// still reflects reality even when admin never bothers allocating a
/// single payment to a specific row.
List<InstallmentRow> computeInstallmentRows({
  required List<InstallmentScheduleItem> installments,
  required List<FeePayment> payments,
  required DateTime now,
}) {
  if (installments.isEmpty) return const [];

  final dueDateOrder = List<int>.generate(installments.length, (i) => i)
    ..sort((a, b) => installments[a].dueDate.compareTo(installments[b].dueDate));

  final active = payments.where((p) => p.status == FeePaymentRecordStatus.active);
  final directlyAllocated = <int, double>{};
  var unallocatedPool = 0.0;
  for (final payment in active) {
    final index = payment.installmentIndex;
    if (index != null && index >= 0 && index < installments.length) {
      directlyAllocated.update(
        index,
        (value) => value + payment.amount,
        ifAbsent: () => payment.amount,
      );
    } else {
      unallocatedPool += payment.amount;
    }
  }

  final paidByIndex = <int, double>{};
  for (final index in dueDateOrder) {
    final amount = installments[index].amount;
    var paid = directlyAllocated[index] ?? 0.0;
    if (unallocatedPool > 0) {
      final gap = (amount - paid).clamp(0.0, amount);
      final fromPool = unallocatedPool < gap ? unallocatedPool : gap;
      paid += fromPool;
      unallocatedPool -= fromPool;
    }
    paidByIndex[index] = paid;
  }

  return List.generate(installments.length, (index) {
    final item = installments[index];
    final paid = paidByIndex[index] ?? 0.0;
    final remaining = (item.amount - paid).clamp(0.0, item.amount);
    final status = remaining <= 0.01
        ? InstallmentDisplayStatus.paid
        : now.isAfter(item.dueDate)
            ? InstallmentDisplayStatus.overdue
            : (paid > 0.01 ? InstallmentDisplayStatus.partiallyPaid : InstallmentDisplayStatus.due);
    return InstallmentRow(
      index: index,
      item: item,
      paidAmount: paid,
      remainingAmount: remaining,
      status: status,
    );
  });
}

/// A student's overall fee status (Set 19 section 19) - derived fresh
/// every time from [finalFee]/[totalPaid]/the installment rows, never
/// stored.
enum FeeStatus {
  paid,
  partiallyPaid,
  due,
  overdue;

  String get label => switch (this) {
    FeeStatus.paid => 'Paid',
    FeeStatus.partiallyPaid => 'Partially Paid',
    FeeStatus.due => 'Due',
    FeeStatus.overdue => 'Overdue',
  };
}

FeeStatus computeFeeStatus({
  required double finalFee,
  required double totalPaid,
  required List<InstallmentRow> installmentRows,
}) {
  final balanceDue = finalFee - totalPaid;
  if (balanceDue <= 0.01) return FeeStatus.paid;
  final hasOverdueInstallment =
      installmentRows.any((row) => row.status == InstallmentDisplayStatus.overdue);
  if (hasOverdueInstallment) return FeeStatus.overdue;
  if (totalPaid > 0.01) return FeeStatus.partiallyPaid;
  return FeeStatus.due;
}
