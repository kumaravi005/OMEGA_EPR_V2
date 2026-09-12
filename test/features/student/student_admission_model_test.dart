import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/features/batches/data/installment_schedule_item.dart';
import 'package:omega_epr_v2/features/student/data/student_admission.dart';
import 'package:omega_epr_v2/features/student/data/student_profile.dart';

void main() {
  test(
    'StudentAdmission round-trips through toMap/fromMap, including installments',
    () {
      final admission = StudentAdmission(
        admissionId: 'admission1',
        studentUid: 'uid1',
        academicSessionId: 'session2026',
        classId: 'class8',
        batchId: 'batch1',
        boardId: 'cbse',
        boardCustomText: null,
        standardFee: 9000,
        finalFee: 7500,
        feeReason: '30% concession approved',
        paymentPlan: PaymentPlan.installment,
        installments: [
          InstallmentScheduleItem(
            label: 'Admission',
            amount: 2000,
            dueDate: DateTime(2026, 4, 10),
          ),
          InstallmentScheduleItem(
            label: '1st installment',
            amount: 3000,
            dueDate: DateTime(2026, 6, 10),
            status: InstallmentStatus.paid,
          ),
        ],
        admissionDate: DateTime(2026, 4, 1),
        active: true,
        configuredByUid: 'admin-uid-1',
        createdAt: DateTime(2026, 4, 1),
        updatedAt: DateTime(2026, 4, 1),
      );

      final restored = StudentAdmission.fromMap(
        admission.admissionId,
        admission.toMap(),
      );

      expect(restored.studentUid, 'uid1');
      expect(restored.academicSessionId, 'session2026');
      expect(restored.classId, 'class8');
      expect(restored.batchId, 'batch1');
      expect(restored.boardId, 'cbse');
      expect(restored.standardFee, 9000);
      expect(restored.finalFee, 7500);
      expect(restored.discountAmount, 1500);
      expect(restored.feeReason, contains('concession'));
      expect(restored.paymentPlan, PaymentPlan.installment);
      expect(restored.installments, hasLength(2));
      expect(restored.installments.first.label, 'Admission');
      expect(restored.installments.last.status, InstallmentStatus.paid);
      expect(restored.active, isTrue);
      expect(restored.configuredByUid, 'admin-uid-1');
    },
  );

  test('discountAmount is zero when there is no discount', () {
    final admission = StudentAdmission(
      admissionId: 'admission2',
      studentUid: 'uid2',
      academicSessionId: 'session2026',
      classId: 'class5',
      batchId: 'batch2',
      standardFee: 700,
      finalFee: 700,
      paymentPlan: PaymentPlan.monthly,
      installments: const [],
      admissionDate: DateTime(2026, 4, 1),
      active: true,
      configuredByUid: 'admin-uid-1',
      createdAt: DateTime(2026, 4, 1),
      updatedAt: DateTime(2026, 4, 1),
    );

    expect(admission.discountAmount, 0);
  });

  test('formatAdmissionNumber pads and prefixes a raw sequence number', () {
    expect(formatAdmissionNumber(1), 'STU0001');
    expect(formatAdmissionNumber(42), 'STU0042');
    expect(formatAdmissionNumber(10000), 'STU10000');
  });
}
