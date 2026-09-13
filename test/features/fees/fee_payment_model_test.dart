import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/features/fees/data/fee_payment.dart';
import 'package:omega_epr_v2/features/student/data/payment.dart';

FeePayment _payment({
  FeePaymentRecordStatus status = FeePaymentRecordStatus.active,
  String? referenceNumber,
  int? installmentIndex,
  String? installmentLabel,
  String? reversedBy,
  DateTime? reversedAt,
  String? reversalReason,
}) {
  final now = DateTime(2026, 4, 1);
  return FeePayment(
    paymentId: 'payment1',
    paymentNumber: 'PAY0007',
    studentId: 'student1',
    admissionId: 'admission1',
    academicSessionId: 'session1',
    classId: 'class9',
    batchId: 'batch1',
    amount: 3000,
    paymentDate: now,
    mode: PaymentMode.upi,
    referenceNumber: referenceNumber,
    installmentIndex: installmentIndex,
    installmentLabel: installmentLabel,
    finalFeeAtPayment: 10000,
    status: status,
    reversedBy: reversedBy,
    reversedAt: reversedAt,
    reversalReason: reversalReason,
    collectedBy: 'admin1',
    createdAt: now,
  );
}

void main() {
  test('round-trips through toMap/fromMap, including admission/session/class/batch context', () {
    final payment = _payment(
      referenceNumber: 'TXN123',
      installmentIndex: 1,
      installmentLabel: 'Installment 2',
    );
    final restored = FeePayment.fromMap(payment.paymentId, payment.toMap());

    expect(restored.paymentNumber, 'PAY0007');
    expect(restored.studentId, 'student1');
    expect(restored.admissionId, 'admission1');
    expect(restored.academicSessionId, 'session1');
    expect(restored.classId, 'class9');
    expect(restored.batchId, 'batch1');
    expect(restored.amount, 3000);
    expect(restored.mode, PaymentMode.upi);
    expect(restored.referenceNumber, 'TXN123');
    expect(restored.installmentIndex, 1);
    expect(restored.installmentLabel, 'Installment 2');
    expect(restored.finalFeeAtPayment, 10000);
    expect(restored.status, FeePaymentRecordStatus.active);
  });

  test('optional fields survive as null when absent', () {
    final payment = _payment();
    final restored = FeePayment.fromMap(payment.paymentId, payment.toMap());

    expect(restored.referenceNumber, isNull);
    expect(restored.remark, isNull);
    expect(restored.installmentIndex, isNull);
    expect(restored.installmentLabel, isNull);
    expect(restored.reversedBy, isNull);
    expect(restored.reversedAt, isNull);
    expect(restored.reversalReason, isNull);
  });

  test('isReversed is false for an active payment', () {
    expect(_payment().isReversed, isFalse);
  });

  group('reversal', () {
    test('isReversed is true once status is reversed', () {
      final payment = _payment(
        status: FeePaymentRecordStatus.reversed,
        reversedBy: 'admin1',
        reversedAt: DateTime(2026, 4, 5),
        reversalReason: 'Entered by mistake',
      );
      expect(payment.isReversed, isTrue);
    });

    test('reversal fields round-trip through toMap/fromMap', () {
      final reversedAt = DateTime(2026, 4, 5);
      final payment = _payment(
        status: FeePaymentRecordStatus.reversed,
        reversedBy: 'admin1',
        reversedAt: reversedAt,
        reversalReason: 'Entered by mistake',
      );
      final restored = FeePayment.fromMap(payment.paymentId, payment.toMap());

      expect(restored.status, FeePaymentRecordStatus.reversed);
      expect(restored.reversedBy, 'admin1');
      expect(restored.reversedAt, reversedAt);
      expect(restored.reversalReason, 'Entered by mistake');
      // The original amount/mode/context are untouched by a reversal.
      expect(restored.amount, 3000);
      expect(restored.mode, PaymentMode.upi);
    });
  });
}
