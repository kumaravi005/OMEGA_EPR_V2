import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/features/fees/data/fee_payment.dart';
import 'package:omega_epr_v2/features/reports/data/payment_report_columns.dart';
import 'package:omega_epr_v2/features/student/data/payment.dart';

FeePayment _payment({
  FeePaymentRecordStatus status = FeePaymentRecordStatus.active,
  String? referenceNumber,
}) {
  final now = DateTime(2026, 4, 1);
  return FeePayment(
    paymentId: 'payment1',
    paymentNumber: 'PAY0001',
    studentId: 'student1',
    admissionId: 'admission1',
    academicSessionId: 'session1',
    classId: 'class9',
    batchId: 'batch1',
    amount: 3000,
    paymentDate: now,
    mode: PaymentMode.upi,
    referenceNumber: referenceNumber,
    finalFeeAtPayment: 10000,
    status: status,
    collectedBy: 'admin1',
    createdAt: now,
  );
}

void main() {
  group('PaymentReportColumns', () {
    test('renders the payment number, resolved names, and mode', () {
      final row = PaymentReportRow(
        payment: _payment(referenceNumber: 'TXN123'),
        studentName: 'Test Student',
        admissionNumber: 'STU0001',
        className: 'Class 9',
        batchName: 'Morning Batch',
        collectedByName: 'Admin One',
      );

      final cells = PaymentReportColumns.row(
        row,
        ['paymentNumber', 'studentName', 'admissionNumber', 'className', 'batchName', 'mode', 'referenceNumber', 'collectedBy'],
      );

      expect(cells, [
        'PAY0001',
        'Test Student',
        'STU0001',
        'Class 9',
        'Morning Batch',
        'UPI',
        'TXN123',
        'Admin One',
      ]);
    });

    test('an active payment shows status Active', () {
      final row = PaymentReportRow(
        payment: _payment(),
        studentName: 'Student',
        admissionNumber: '',
        className: 'Class 9',
        batchName: 'Batch',
        collectedByName: 'Admin',
      );
      expect(PaymentReportColumns.row(row, ['status']), ['Active']);
    });

    test('a reversed payment remains visible with status Reversed, never hidden', () {
      final row = PaymentReportRow(
        payment: _payment(status: FeePaymentRecordStatus.reversed),
        studentName: 'Student',
        admissionNumber: '',
        className: 'Class 9',
        batchName: 'Batch',
        collectedByName: 'Admin',
      );
      expect(PaymentReportColumns.row(row, ['status']), ['Reversed']);
      // The amount/payment number stay exactly as recorded, unaffected by reversal.
      expect(PaymentReportColumns.row(row, ['paymentNumber', 'amount']), ['PAY0001', 'Rs. 3000']);
    });

    test('missing admission number and reference number render as "-"', () {
      final row = PaymentReportRow(
        payment: _payment(referenceNumber: null),
        studentName: 'Student',
        admissionNumber: '',
        className: 'Class 9',
        batchName: 'Batch',
        collectedByName: 'Admin',
      );
      expect(
        PaymentReportColumns.row(row, ['admissionNumber', 'referenceNumber']),
        ['-', '-'],
      );
    });
  });
}
