import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/data/models/gender.dart';
import 'package:omega_epr_v2/features/fees/data/fee_calculator.dart';
import 'package:omega_epr_v2/features/reports/data/fee_report_columns.dart';
import 'package:omega_epr_v2/features/student/data/student_admission.dart';
import 'package:omega_epr_v2/features/student/data/student_profile.dart';

StudentProfile _student() {
  final now = DateTime(2026, 1, 1);
  return StudentProfile(
    uid: 'student1',
    accountId: 'stu001',
    admissionNumber: 'STU0001',
    name: 'Test Student',
    fatherName: 'Test Father',
    dateOfBirth: DateTime(2010, 1, 1),
    gender: Gender.male,
    address: 'Address',
    className: 'Class 9',
    board: 'CBSE',
    batchId: 'batch1',
    academicSession: '2026-27',
    academicSessionId: 'session1',
    classId: 'class9',
    primaryMobile: '9876543210',
    secondaryMobile: null,
    standardFee: 12000,
    finalFee: 10000,
    feeReason: 'Sibling discount',
    paymentPlan: PaymentPlan.installment,
    admissionDate: now,
    currentAdmissionId: 'admission1',
    active: true,
    createdAt: now,
    updatedAt: now,
  );
}

StudentAdmission _admission() {
  final now = DateTime(2026, 1, 1);
  return StudentAdmission(
    admissionId: 'admission1',
    studentUid: 'student1',
    academicSessionId: 'session1',
    classId: 'class9',
    batchId: 'batch1',
    standardFee: 12000,
    finalFee: 10000,
    feeReason: 'Sibling discount',
    paymentPlan: PaymentPlan.installment,
    installments: const [],
    admissionDate: now,
    active: true,
    configuredByUid: 'admin1',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('FeeReportColumns', () {
    test('standardFee/finalFee/remark come from the admission, not the profile', () {
      final row = FeeReportRow(
        student: _student(),
        admission: _admission(),
        batchName: 'Morning Batch',
        totalPaid: 6000,
        balanceDue: 4000,
        status: FeeStatus.partiallyPaid,
        lastPaymentDate: DateTime(2026, 3, 10),
      );

      final cells = FeeReportColumns.row(
        row,
        ['standardFee', 'finalFee', 'remark', 'status', 'lastPaymentDate', 'due', 'paid'],
      );

      expect(cells[0], 'Rs. 12000');
      expect(cells[1], 'Rs. 10000');
      expect(cells[2], 'Sibling discount');
      expect(cells[3], 'Partially Paid');
      expect(cells[4], '2026-03-10');
      expect(cells[5], 'Rs. 4000');
      expect(cells[6], 'Rs. 6000');
    });

    test('a student with no active admission shows "-" for admission-derived fields', () {
      final row = FeeReportRow(
        student: _student(),
        admission: null,
        batchName: 'Morning Batch',
        totalPaid: 0,
        balanceDue: 0,
        status: null,
        lastPaymentDate: null,
      );

      final cells = FeeReportColumns.row(
        row,
        ['standardFee', 'finalFee', 'remark', 'status', 'lastPaymentDate'],
      );

      expect(cells, ['-', '-', '-', '-', '-']);
    });

    test('due shows "Paid in full" when the balance is settled', () {
      final row = FeeReportRow(
        student: _student(),
        admission: _admission(),
        batchName: 'Batch',
        totalPaid: 10000,
        balanceDue: 0,
        status: FeeStatus.paid,
        lastPaymentDate: DateTime(2026, 3, 1),
      );
      expect(FeeReportColumns.row(row, ['due']), ['Paid in full']);
    });

    test('due shows an advance when overpaid', () {
      final row = FeeReportRow(
        student: _student(),
        admission: _admission(),
        batchName: 'Batch',
        totalPaid: 10500,
        balanceDue: -500,
        status: FeeStatus.paid,
        lastPaymentDate: DateTime(2026, 3, 1),
      );
      expect(FeeReportColumns.row(row, ['due']), ['Advance Rs. 500']);
    });

    test('the fee-due-report and staff-contact-list presets differ', () {
      expect(FeeReportColumns.defaultFeeDueKeys, isNot(FeeReportColumns.defaultStaffContactKeys));
      expect(FeeReportColumns.defaultFeeDueKeys.contains('status'), isTrue);
      expect(FeeReportColumns.defaultStaffContactKeys.contains('lastPaymentDate'), isTrue);
    });
  });
}
