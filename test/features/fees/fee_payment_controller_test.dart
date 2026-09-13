import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/data/models/gender.dart';
import 'package:omega_epr_v2/features/fees/application/fee_payment_controller.dart';
import 'package:omega_epr_v2/features/fees/data/fee_payment.dart';
import 'package:omega_epr_v2/features/student/data/payment.dart';
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
    address: '123 Main St',
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

StudentAdmission _admission({bool active = true, double finalFee = 10000}) {
  final now = DateTime(2026, 1, 1);
  return StudentAdmission(
    admissionId: 'admission1',
    studentUid: 'student1',
    academicSessionId: 'session1',
    classId: 'class9',
    batchId: 'batch1',
    standardFee: 12000,
    finalFee: finalFee,
    feeReason: 'Sibling discount',
    paymentPlan: PaymentPlan.installment,
    installments: const [],
    admissionDate: now,
    active: active,
    configuredByUid: 'admin1',
    createdAt: now,
    updatedAt: now,
  );
}

FeePayment _feePayment({FeePaymentRecordStatus status = FeePaymentRecordStatus.active}) {
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
    mode: PaymentMode.cash,
    finalFeeAtPayment: 10000,
    status: status,
    collectedBy: 'admin1',
    createdAt: now,
  );
}

void main() {
  group('FeePaymentController.recordPayment validation', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('rejects a zero amount', () {
      final controller = container.read(feePaymentControllerProvider);
      expect(
        () => controller.recordPayment(
          student: _student(),
          admission: _admission(),
          amount: 0,
          paymentDate: DateTime(2026, 4, 1),
          mode: PaymentMode.cash,
          currentDue: 10000,
        ),
        throwsA(
          isA<FeePaymentFailure>().having((f) => f.message, 'message', contains('greater than zero')),
        ),
      );
    });

    test('rejects a negative amount', () {
      final controller = container.read(feePaymentControllerProvider);
      expect(
        () => controller.recordPayment(
          student: _student(),
          admission: _admission(),
          amount: -500,
          paymentDate: DateTime(2026, 4, 1),
          mode: PaymentMode.cash,
          currentDue: 10000,
        ),
        throwsA(isA<FeePaymentFailure>()),
      );
    });

    test('rejects a payment against an inactive admission', () {
      final controller = container.read(feePaymentControllerProvider);
      expect(
        () => controller.recordPayment(
          student: _student(),
          admission: _admission(active: false),
          amount: 1000,
          paymentDate: DateTime(2026, 4, 1),
          mode: PaymentMode.cash,
          currentDue: 10000,
        ),
        throwsA(
          isA<FeePaymentFailure>().having((f) => f.message, 'message', contains('no longer active')),
        ),
      );
    });

    test('rejects an amount exceeding the outstanding balance', () {
      final controller = container.read(feePaymentControllerProvider);
      expect(
        () => controller.recordPayment(
          student: _student(),
          admission: _admission(),
          amount: 5000,
          paymentDate: DateTime(2026, 4, 1),
          mode: PaymentMode.cash,
          currentDue: 4000,
        ),
        throwsA(
          isA<FeePaymentFailure>().having((f) => f.message, 'message', contains('exceed')),
        ),
      );
    });

    test('accepts an amount exactly equal to the outstanding balance', () {
      final controller = container.read(feePaymentControllerProvider);
      // Passes every validation rule - the only remaining failure (no
      // signed-in admin in this bare container) proves the amount itself
      // was never the problem.
      expect(
        () => controller.recordPayment(
          student: _student(),
          admission: _admission(),
          amount: 4000,
          paymentDate: DateTime(2026, 4, 1),
          mode: PaymentMode.cash,
          currentDue: 4000,
        ),
        throwsA(
          isA<FeePaymentFailure>().having(
            (f) => f.message,
            'message',
            contains('sign in'),
          ),
        ),
      );
    });
  });

  group('FeePaymentController.reversePayment validation', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('rejects reversing an already-reversed payment', () {
      final controller = container.read(feePaymentControllerProvider);
      expect(
        () => controller.reversePayment(
          _feePayment(status: FeePaymentRecordStatus.reversed),
          'Duplicate entry',
        ),
        throwsA(
          isA<FeePaymentFailure>().having((f) => f.message, 'message', contains('already been reversed')),
        ),
      );
    });

    test('rejects an empty reversal reason', () {
      final controller = container.read(feePaymentControllerProvider);
      expect(
        () => controller.reversePayment(_feePayment(), '   '),
        throwsA(
          isA<FeePaymentFailure>().having((f) => f.message, 'message', contains('reason')),
        ),
      );
    });
  });
}
