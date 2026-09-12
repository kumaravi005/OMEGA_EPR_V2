import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/features/batches/data/batch.dart';
import 'package:omega_epr_v2/features/batches/data/batch_repository.dart';

Batch _batch({
  required String batchId,
  required String academicSessionId,
  required String classId,
}) {
  final now = DateTime(2026, 1, 1);
  return Batch(
    batchId: batchId,
    name: 'Batch $batchId',
    academicSessionId: academicSessionId,
    classId: classId,
    standardMonthlyFee: 700,
    standardInstallmentFee: 8000,
    active: true,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  final batches = [
    _batch(batchId: 'b1', academicSessionId: 's2026', classId: 'c5'),
    _batch(batchId: 'b2', academicSessionId: 's2026', classId: 'c6'),
    _batch(batchId: 'b3', academicSessionId: 's2027', classId: 'c5'),
  ];

  test(
    'returns only batches matching BOTH the session and the class',
    () {
      final matching = batchesForSessionAndClass(
        batches,
        academicSessionId: 's2026',
        classId: 'c5',
      );
      expect(matching.map((b) => b.batchId), ['b1']);
    },
  );

  test(
    'the same class name/id in a different session never leaks into the match',
    () {
      final matching = batchesForSessionAndClass(
        batches,
        academicSessionId: 's2027',
        classId: 'c5',
      );
      expect(matching.map((b) => b.batchId), ['b3']);
    },
  );

  test('returns nothing until both session and class are chosen', () {
    expect(
      batchesForSessionAndClass(batches, academicSessionId: null, classId: 'c5'),
      isEmpty,
    );
    expect(
      batchesForSessionAndClass(batches, academicSessionId: 's2026', classId: null),
      isEmpty,
    );
  });
}
