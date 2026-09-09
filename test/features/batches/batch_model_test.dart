import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/features/batches/data/batch.dart';

void main() {
  test('Batch round-trips through toMap/fromMap', () {
    final batch = Batch(
      batchId: 'batch1',
      name: 'Class 8 - Science Morning',
      standardMonthlyFee: 3000,
      standardInstallmentFee: 9000,
      active: true,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 2),
    );

    final restored = Batch.fromMap(batch.batchId, batch.toMap());

    expect(restored.name, batch.name);
    expect(restored.standardMonthlyFee, batch.standardMonthlyFee);
    expect(restored.standardInstallmentFee, batch.standardInstallmentFee);
    expect(restored.active, batch.active);
    expect(restored.createdAt, batch.createdAt);
  });
}
