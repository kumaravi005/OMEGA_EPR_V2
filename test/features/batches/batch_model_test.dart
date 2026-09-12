import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/features/batches/data/batch.dart';

void main() {
  test('Batch round-trips through toMap/fromMap, including Set 10 fields', () {
    final batch = Batch(
      batchId: 'batch1',
      name: 'Class 8 - Science Morning',
      batchCode: 'C8-MOR',
      description: 'Morning batch for Class 8 science stream',
      academicSessionId: 'session2026',
      classId: 'class8',
      boardId: 'cbse',
      boardCustomText: null,
      standardMonthlyFee: 3000,
      standardInstallmentFee: 9000,
      active: true,
      studentCount: 12,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 2),
    );

    final restored = Batch.fromMap(batch.batchId, batch.toMap());

    expect(restored.name, batch.name);
    expect(restored.batchCode, 'C8-MOR');
    expect(restored.description, batch.description);
    expect(restored.academicSessionId, 'session2026');
    expect(restored.classId, 'class8');
    expect(restored.boardId, 'cbse');
    expect(restored.standardMonthlyFee, batch.standardMonthlyFee);
    expect(restored.standardInstallmentFee, batch.standardInstallmentFee);
    expect(restored.active, batch.active);
    expect(restored.studentCount, 12);
    expect(restored.createdAt, batch.createdAt);
    expect(restored.isLinkedToMasterData, isTrue);
  });

  test(
    'Batch.fromMap defaults session/class to empty strings when absent (pre-Set-10 batches)',
    () {
      final restored = Batch.fromMap('oldBatch', {
        'name': 'Class 10 Evening',
        'standardMonthlyFee': 2500,
        'standardInstallmentFee': 8000,
        'active': true,
        'createdAt': Timestamp.fromDate(DateTime(2025, 1, 1)),
        'updatedAt': Timestamp.fromDate(DateTime(2025, 1, 1)),
      });

      expect(restored.academicSessionId, '');
      expect(restored.classId, '');
      expect(restored.isLinkedToMasterData, isFalse);
      expect(restored.studentCount, 0);
    },
  );

  test('standardFeeFor returns the installment fee only when asked for it', () {
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

    expect(batch.standardFeeFor(isInstallment: false), 700);
    expect(batch.standardFeeFor(isInstallment: true), 8000);
  });
}
