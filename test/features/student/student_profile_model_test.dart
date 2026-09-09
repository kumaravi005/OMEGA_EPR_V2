import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/data/models/gender.dart';
import 'package:omega_epr_v2/features/student/data/student_profile.dart';

void main() {
  test('StudentProfile round-trips through toMap/fromMap, including the fee reason', () {
    final student = StudentProfile(
      uid: 'uid1',
      accountId: 'stu2026001',
      name: 'Test Student',
      fatherName: 'Test Father',
      dateOfBirth: DateTime(2012, 5, 1),
      gender: Gender.male,
      address: '123 Street',
      className: 'Class 8',
      board: 'CBSE',
      batchId: 'batch1',
      academicSession: '2026-27',
      primaryMobile: '9999999999',
      secondaryMobile: '8888888888',
      standardFee: 9000,
      finalFee: 7500,
      feeReason: 'approved discount',
      paymentPlan: PaymentPlan.monthly,
      active: true,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final restored = StudentProfile.fromMap(student.uid, student.toMap());

    expect(restored.standardFee, 9000);
    expect(restored.finalFee, 7500);
    expect(restored.feeReason, 'approved discount');
    expect(restored.discount, 1500);
    expect(restored.paymentPlan, PaymentPlan.monthly);
    expect(restored.batchId, 'batch1');
  });

  test('feeReason survives as null when the final fee matches the standard fee', () {
    final student = StudentProfile(
      uid: 'uid2',
      accountId: 'stu2026002',
      name: 'No Discount Student',
      fatherName: 'Father',
      dateOfBirth: DateTime(2013, 1, 1),
      gender: Gender.female,
      address: 'Address',
      className: 'Class 6',
      board: 'ICSE',
      batchId: 'batch2',
      academicSession: '2026-27',
      primaryMobile: '7000000000',
      secondaryMobile: null,
      standardFee: 5000,
      finalFee: 5000,
      feeReason: null,
      paymentPlan: PaymentPlan.installment,
      active: true,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final restored = StudentProfile.fromMap(student.uid, student.toMap());

    expect(restored.feeReason, isNull);
    expect(restored.discount, 0);
  });
}
