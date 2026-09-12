import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/data/models/gender.dart';
import 'package:omega_epr_v2/features/student/data/student_profile.dart';

void main() {
  test(
    'StudentProfile round-trips through toMap/fromMap, including Set 11 fields',
    () {
      final student = StudentProfile(
        uid: 'uid1',
        accountId: 'stu2026001',
        admissionNumber: 'STU0001',
        name: 'Test Student',
        fatherName: 'Test Father',
        dateOfBirth: DateTime(2012, 5, 1),
        gender: Gender.male,
        photoUrl: 'https://example.com/photo.jpg',
        address: '123 Street',
        className: 'Class 8',
        board: 'CBSE',
        batchId: 'batch1',
        academicSession: '2026-27',
        academicSessionId: 'session2026',
        classId: 'class8',
        boardId: 'cbse',
        boardCustomText: null,
        primaryMobile: '9999999999',
        secondaryMobile: '8888888888',
        standardFee: 9000,
        finalFee: 7500,
        feeReason: 'approved discount',
        paymentPlan: PaymentPlan.monthly,
        admissionDate: DateTime(2026, 1, 1),
        currentAdmissionId: 'admission1',
        active: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final restored = StudentProfile.fromMap(student.uid, student.toMap());

      expect(restored.admissionNumber, 'STU0001');
      expect(restored.photoUrl, 'https://example.com/photo.jpg');
      expect(restored.academicSessionId, 'session2026');
      expect(restored.classId, 'class8');
      expect(restored.currentAdmissionId, 'admission1');
      expect(restored.standardFee, 9000);
      expect(restored.finalFee, 7500);
      expect(restored.feeReason, 'approved discount');
      expect(restored.discount, 1500);
      expect(restored.paymentPlan, PaymentPlan.monthly);
      expect(restored.batchId, 'batch1');
      expect(restored.isLinkedToMasterData, isTrue);
    },
  );

  test(
    'feeReason survives as null when the final fee matches the standard fee',
    () {
      final student = StudentProfile(
        uid: 'uid2',
        accountId: 'stu2026002',
        admissionNumber: 'STU0002',
        name: 'No Discount Student',
        fatherName: 'Father',
        dateOfBirth: DateTime(2013, 1, 1),
        gender: Gender.female,
        address: 'Address',
        className: 'Class 6',
        board: 'ICSE',
        batchId: 'batch2',
        academicSession: '2026-27',
        academicSessionId: 'session2026',
        classId: 'class6',
        primaryMobile: '7000000000',
        secondaryMobile: null,
        standardFee: 5000,
        finalFee: 5000,
        feeReason: null,
        paymentPlan: PaymentPlan.installment,
        admissionDate: DateTime(2026, 1, 1),
        currentAdmissionId: 'admission2',
        active: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final restored = StudentProfile.fromMap(student.uid, student.toMap());

      expect(restored.feeReason, isNull);
      expect(restored.discount, 0);
      expect(restored.photoUrl, isNull);
    },
  );

  test(
    'fromMap defaults admissionNumber/session/class/currentAdmissionId '
    'to empty strings, and admissionDate to createdAt, on a pre-Set-11 '
    'student document',
    () {
      final restored = StudentProfile.fromMap('oldStudent', {
        'accountId': 'stu2020001',
        'name': 'Old Student',
        'fatherName': 'Father',
        'dateOfBirth': Timestamp.fromDate(DateTime(2010, 1, 1)),
        'gender': 'male',
        'address': 'Address',
        'className': 'Class 9',
        'board': 'CBSE',
        'batchId': 'batch1',
        'academicSession': '2020-21',
        'primaryMobile': '9999999999',
        'standardFee': 5000,
        'finalFee': 5000,
        'feeReason': null,
        'paymentPlan': 'monthly',
        'active': true,
        'createdAt': Timestamp.fromDate(DateTime(2020, 4, 1)),
        'updatedAt': Timestamp.fromDate(DateTime(2020, 4, 1)),
      });

      expect(restored.admissionNumber, '');
      expect(restored.academicSessionId, '');
      expect(restored.classId, '');
      expect(restored.currentAdmissionId, '');
      expect(restored.isLinkedToMasterData, isFalse);
      expect(restored.admissionDate, DateTime(2020, 4, 1));
    },
  );
}
