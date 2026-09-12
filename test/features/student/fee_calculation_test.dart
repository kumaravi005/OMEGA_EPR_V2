import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/data/models/gender.dart';
import 'package:omega_epr_v2/features/student/data/payment.dart';
import 'package:omega_epr_v2/features/student/data/student_profile.dart';
import 'package:omega_epr_v2/features/student/data/student_repository.dart';

StudentProfile _student({
  required double standardFee,
  required double finalFee,
}) {
  final now = DateTime(2026, 1, 1);
  return StudentProfile(
    uid: 'stu1',
    accountId: 'stu2026001',
    admissionNumber: 'STU0001',
    name: 'Test Student',
    fatherName: 'Test Father',
    dateOfBirth: DateTime(2012, 5, 1),
    gender: Gender.male,
    address: '123 Street',
    className: 'Class 8',
    board: 'CBSE',
    batchId: 'batch1',
    academicSession: '2026-27',
    academicSessionId: 'session2026',
    classId: 'class8',
    primaryMobile: '9999999999',
    secondaryMobile: null,
    standardFee: standardFee,
    finalFee: finalFee,
    feeReason: standardFee == finalFee ? null : 'approved discount',
    paymentPlan: PaymentPlan.monthly,
    admissionDate: now,
    currentAdmissionId: 'admission1',
    active: true,
    createdAt: now,
    updatedAt: now,
  );
}

Payment _payment(double amount) {
  final now = DateTime(2026, 2, 1);
  return Payment(
    paymentId: 'p1',
    amount: amount,
    date: now,
    mode: PaymentMode.cash,
    remark: null,
    createdAt: now,
    createdBy: 'admin1',
  );
}

void main() {
  group('fee calculations', () {
    test(
      'uses the final fee, not the standard fee, for due calculation with no payments',
      () {
        final student = _student(standardFee: 9000, finalFee: 7500);
        expect(due(student, []), 7500);
      },
    );

    test('discount is standard fee minus final fee', () {
      final student = _student(standardFee: 9000, finalFee: 7500);
      expect(student.discount, 1500);
    });

    test('no discount when final fee equals standard fee', () {
      final student = _student(standardFee: 9000, finalFee: 9000);
      expect(student.discount, 0);
    });

    test('totalPaid sums all payments', () {
      final payments = [_payment(2000), _payment(1500), _payment(500)];
      expect(totalPaid(payments), 4000);
    });

    test('due reduces as payments come in, based on final fee', () {
      final student = _student(standardFee: 9000, finalFee: 7500);
      final payments = [_payment(3000), _payment(2000)];
      expect(due(student, payments), 2500);
    });

    test('due can reach zero when fully paid', () {
      final student = _student(standardFee: 9000, finalFee: 7500);
      final payments = [_payment(7500)];
      expect(due(student, payments), 0);
    });
  });

  group('dueLabel', () {
    test('shows Due when the student still owes money', () {
      expect(dueLabel(500), 'Due ₹500');
    });

    test('shows Advance when the student has overpaid', () {
      expect(dueLabel(-200), 'Advance ₹200');
    });

    test('shows Paid in full when exactly settled', () {
      expect(dueLabel(0), 'Paid in full');
    });
  });
}
