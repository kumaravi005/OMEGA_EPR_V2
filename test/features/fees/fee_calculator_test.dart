import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/features/batches/data/installment_schedule_item.dart';
import 'package:omega_epr_v2/features/fees/data/fee_calculator.dart';
import 'package:omega_epr_v2/features/fees/data/fee_payment.dart';
import 'package:omega_epr_v2/features/student/data/payment.dart';

FeePayment _payment({
  String paymentId = 'p1',
  double amount = 1000,
  FeePaymentRecordStatus status = FeePaymentRecordStatus.active,
  int? installmentIndex,
  DateTime? paymentDate,
}) {
  final now = DateTime(2026, 4, 1);
  return FeePayment(
    paymentId: paymentId,
    paymentNumber: 'PAY0001',
    studentId: 'student1',
    admissionId: 'admission1',
    academicSessionId: 'session1',
    classId: 'class9',
    batchId: 'batch1',
    amount: amount,
    paymentDate: paymentDate ?? now,
    mode: PaymentMode.cash,
    installmentIndex: installmentIndex,
    finalFeeAtPayment: 10000,
    status: status,
    collectedBy: 'admin1',
    createdAt: now,
  );
}

Payment _legacyPayment(double amount, {DateTime? date}) {
  final now = DateTime(2026, 1, 1);
  return Payment(
    paymentId: 'legacy1',
    amount: amount,
    date: date ?? now,
    mode: PaymentMode.cash,
    remark: null,
    createdAt: now,
    createdBy: 'admin1',
  );
}

void main() {
  group('totalActiveFeePaymentAmount', () {
    test('sums only active payments', () {
      final payments = [
        _payment(amount: 3000),
        _payment(amount: 2000, status: FeePaymentRecordStatus.reversed),
      ];
      expect(totalActiveFeePaymentAmount(payments), 3000);
    });

    test('is zero for an empty list', () {
      expect(totalActiveFeePaymentAmount(const []), 0);
    });
  });

  group('totalReversedFeePaymentAmount', () {
    test('sums only reversed payments', () {
      final payments = [
        _payment(amount: 3000),
        _payment(amount: 2000, status: FeePaymentRecordStatus.reversed),
        _payment(amount: 500, status: FeePaymentRecordStatus.reversed),
      ];
      expect(totalReversedFeePaymentAmount(payments), 2500);
    });
  });

  group('combinedTotalPaid / combinedBalanceDue', () {
    test('combines active new-ledger payments with legacy payments', () {
      final feePayments = [_payment(amount: 3000)];
      final legacyPayments = [_legacyPayment(1000)];
      expect(
        combinedTotalPaid(feePayments: feePayments, legacyPayments: legacyPayments),
        4000,
      );
    });

    test('excludes reversed payments from the combined total', () {
      final feePayments = [
        _payment(amount: 3000),
        _payment(amount: 5000, status: FeePaymentRecordStatus.reversed),
      ];
      expect(
        combinedTotalPaid(feePayments: feePayments, legacyPayments: const []),
        3000,
      );
    });

    test('uses the final fee, never the standard fee, for due calculation', () {
      // Standard = 12000, discount = 2000, final = 10000, paid = 6000 -> due = 4000.
      final feePayments = [_payment(amount: 6000)];
      final due = combinedBalanceDue(
        finalFee: 10000,
        feePayments: feePayments,
        legacyPayments: const [],
      );
      expect(due, 4000);
    });

    test('discount is respected in the due calculation via finalFee', () {
      final due = combinedBalanceDue(
        finalFee: 8000,
        feePayments: [_payment(amount: 8000)],
        legacyPayments: const [],
      );
      expect(due, 0);
    });
  });

  group('lastPaymentDate', () {
    test('is null when nothing has ever been paid', () {
      expect(
        lastPaymentDate(feePayments: const [], legacyPayments: const []),
        isNull,
      );
    });

    test('picks the most recent date across both new and legacy payments', () {
      final result = lastPaymentDate(
        feePayments: [_payment(paymentDate: DateTime(2026, 3, 1))],
        legacyPayments: [_legacyPayment(1000, date: DateTime(2026, 4, 15))],
      );
      expect(result, DateTime(2026, 4, 15));
    });

    test('excludes a reversed payment even if it is the most recent one', () {
      final result = lastPaymentDate(
        feePayments: [
          _payment(paymentDate: DateTime(2026, 3, 1)),
          _payment(
            paymentDate: DateTime(2026, 5, 1),
            status: FeePaymentRecordStatus.reversed,
          ),
        ],
        legacyPayments: const [],
      );
      expect(result, DateTime(2026, 3, 1));
    });

    test('every legacy payment counts - that collection has no reversal concept', () {
      final result = lastPaymentDate(
        feePayments: const [],
        legacyPayments: [_legacyPayment(500, date: DateTime(2026, 2, 1))],
      );
      expect(result, DateTime(2026, 2, 1));
    });
  });

  group('computeInstallmentRows', () {
    List<InstallmentScheduleItem> installments({DateTime? due1, DateTime? due2}) => [
      InstallmentScheduleItem(label: 'Installment 1', amount: 3000, dueDate: due1 ?? DateTime(2026, 2, 1)),
      InstallmentScheduleItem(label: 'Installment 2', amount: 3000, dueDate: due2 ?? DateTime(2026, 5, 1)),
    ];

    test('returns nothing for an empty schedule', () {
      expect(
        computeInstallmentRows(installments: const [], payments: const [], now: DateTime(2026, 1, 1)),
        isEmpty,
      );
    });

    test('a directly-allocated payment marks that installment fully paid', () {
      final rows = computeInstallmentRows(
        installments: installments(),
        payments: [_payment(amount: 3000, installmentIndex: 0)],
        now: DateTime(2026, 1, 15),
      );
      expect(rows[0].status, InstallmentDisplayStatus.paid);
      expect(rows[0].paidAmount, 3000);
      expect(rows[1].status, InstallmentDisplayStatus.due);
    });

    test('a partial direct allocation is Partially Paid', () {
      final rows = computeInstallmentRows(
        installments: installments(),
        payments: [_payment(amount: 1500, installmentIndex: 0)],
        now: DateTime(2026, 1, 15),
      );
      expect(rows[0].status, InstallmentDisplayStatus.partiallyPaid);
      expect(rows[0].paidAmount, 1500);
      expect(rows[0].remainingAmount, 1500);
    });

    test('an unallocated payment fills the earliest-due installment first', () {
      final rows = computeInstallmentRows(
        installments: installments(),
        payments: [_payment(amount: 3000)],
        now: DateTime(2026, 1, 15),
      );
      expect(rows[0].status, InstallmentDisplayStatus.paid);
      expect(rows[1].status, InstallmentDisplayStatus.due);
    });

    test('an unallocated payment spans into the second installment once the first is covered', () {
      final rows = computeInstallmentRows(
        installments: installments(),
        payments: [_payment(amount: 4000)],
        now: DateTime(2026, 1, 15),
      );
      expect(rows[0].status, InstallmentDisplayStatus.paid);
      expect(rows[1].status, InstallmentDisplayStatus.partiallyPaid);
      expect(rows[1].paidAmount, 1000);
    });

    test('an installment past its due date with a remaining balance is overdue', () {
      final rows = computeInstallmentRows(
        installments: installments(),
        payments: const [],
        now: DateTime(2026, 3, 1),
      );
      expect(rows[0].status, InstallmentDisplayStatus.overdue);
      expect(rows[1].status, InstallmentDisplayStatus.due);
    });

    test('a fully paid installment never becomes overdue, even long past its due date', () {
      final rows = computeInstallmentRows(
        installments: installments(),
        payments: [_payment(amount: 3000, installmentIndex: 0)],
        now: DateTime(2027, 1, 1),
      );
      expect(rows[0].status, InstallmentDisplayStatus.paid);
    });

    test('a reversed payment does not count toward any installment allocation', () {
      final rows = computeInstallmentRows(
        installments: installments(),
        payments: [_payment(amount: 3000, installmentIndex: 0, status: FeePaymentRecordStatus.reversed)],
        now: DateTime(2026, 1, 15),
      );
      expect(rows[0].status, InstallmentDisplayStatus.due);
      expect(rows[0].paidAmount, 0);
    });
  });

  group('computeFeeStatus', () {
    test('fully paid shows Paid', () {
      final status = computeFeeStatus(finalFee: 10000, totalPaid: 10000, installmentRows: const []);
      expect(status, FeeStatus.paid);
    });

    test('overpaid (advance) still shows Paid', () {
      final status = computeFeeStatus(finalFee: 10000, totalPaid: 10500, installmentRows: const []);
      expect(status, FeeStatus.paid);
    });

    test('partially paid with no overdue installment shows Partially Paid', () {
      final status = computeFeeStatus(finalFee: 10000, totalPaid: 4000, installmentRows: const []);
      expect(status, FeeStatus.partiallyPaid);
    });

    test('nothing paid and no overdue installment shows Due', () {
      final status = computeFeeStatus(finalFee: 10000, totalPaid: 0, installmentRows: const []);
      expect(status, FeeStatus.due);
    });

    test('any overdue installment overrides Partially Paid to Overdue', () {
      final overdueRow = InstallmentRow(
        index: 0,
        item: InstallmentScheduleItem(label: 'Installment 1', amount: 3000, dueDate: DateTime(2020, 1, 1)),
        paidAmount: 0,
        remainingAmount: 3000,
        status: InstallmentDisplayStatus.overdue,
      );
      final status = computeFeeStatus(
        finalFee: 10000,
        totalPaid: 4000,
        installmentRows: [overdueRow],
      );
      expect(status, FeeStatus.overdue);
    });
  });

  group('formatPaymentNumber', () {
    test('pads and prefixes a raw sequence number', () {
      expect(formatPaymentNumber(1), 'PAY0001');
      expect(formatPaymentNumber(42), 'PAY0042');
      expect(formatPaymentNumber(10000), 'PAY10000');
    });
  });
}
