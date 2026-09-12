import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/features/batches/data/batch.dart';
import 'package:omega_epr_v2/features/batches/data/negotiated_fee.dart';

void main() {
  test(
    'NegotiatedFee round-trips through toMap/fromMap and computes the discount',
    () {
      final fee = NegotiatedFee(
        standardFee: 700,
        finalFee: 500,
        isInstallmentPlan: false,
        remark: '30% concession approved based on financial circumstances.',
        effectiveDate: DateTime(2026, 4, 1),
        configuredByUid: 'admin-uid-1',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final restored = NegotiatedFee.fromMap(fee.toMap());

      expect(restored.standardFee, 700);
      expect(restored.finalFee, 500);
      expect(restored.discountAmount, 200);
      expect(restored.remark, contains('concession'));
      expect(restored.configuredByUid, 'admin-uid-1');
      expect(restored.effectiveDate, DateTime(2026, 4, 1));
    },
  );

  test(
    'a negotiated (discounted) fee never changes the batch it was snapshotted from',
    () {
      final batch = Batch(
        batchId: 'batch1',
        name: 'Class 5 Morning',
        academicSessionId: 'session2026',
        classId: 'class5',
        standardMonthlyFee: 700,
        standardInstallmentFee: 8000,
        active: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final negotiated = NegotiatedFee(
        standardFee: batch.standardFeeFor(isInstallment: false),
        finalFee: 500,
        isInstallmentPlan: false,
        remark: 'Discount approved',
        configuredByUid: 'admin-uid-1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // The batch's own standard fee is untouched by the student-specific
      // negotiation - nothing in NegotiatedFee writes back to Batch.
      expect(batch.standardMonthlyFee, 700);
      expect(negotiated.discountAmount, 200);
    },
  );

  test('discountAmount is negative when the agreed fee exceeds standard', () {
    final fee = NegotiatedFee(
      standardFee: 700,
      finalFee: 750,
      isInstallmentPlan: false,
      configuredByUid: 'admin-uid-1',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    expect(fee.discountAmount, -50);
  });
}
