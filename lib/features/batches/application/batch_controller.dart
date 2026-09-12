import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/batch.dart';
import '../data/batch_repository.dart';

class BatchFailure implements Exception {
  const BatchFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

final batchControllerProvider = Provider<BatchController>(
  (ref) => BatchController(ref),
);

class BatchController {
  BatchController(this._ref);

  final Ref _ref;

  Future<void> createBatch({
    required String name,
    String? batchCode,
    String? description,
    required String academicSessionId,
    required String classId,
    String? boardId,
    String? boardCustomText,
    required double standardMonthlyFee,
    required double standardInstallmentFee,
  }) async {
    try {
      final now = DateTime.now();
      await _ref
          .read(batchRepositoryProvider)
          .add(
            Batch(
              batchId: '',
              name: name.trim(),
              batchCode: _blankToNull(batchCode),
              description: _blankToNull(description),
              academicSessionId: academicSessionId,
              classId: classId,
              boardId: boardId,
              boardCustomText: _blankToNull(boardCustomText),
              standardMonthlyFee: standardMonthlyFee,
              standardInstallmentFee: standardInstallmentFee,
              active: true,
              createdAt: now,
              updatedAt: now,
            ),
          );
    } catch (_) {
      throw const BatchFailure('Could not create the batch. Please try again.');
    }
  }

  Future<void> updateBatch(
    Batch existing, {
    required String name,
    String? batchCode,
    String? description,
    required String academicSessionId,
    required String classId,
    String? boardId,
    String? boardCustomText,
    required double standardMonthlyFee,
    required double standardInstallmentFee,
  }) async {
    try {
      await _ref
          .read(batchRepositoryProvider)
          .set(
            existing.batchId,
            Batch(
              batchId: existing.batchId,
              name: name.trim(),
              batchCode: _blankToNull(batchCode),
              description: _blankToNull(description),
              academicSessionId: academicSessionId,
              classId: classId,
              boardId: boardId,
              boardCustomText: _blankToNull(boardCustomText),
              standardMonthlyFee: standardMonthlyFee,
              standardInstallmentFee: standardInstallmentFee,
              active: existing.active,
              studentCount: existing.studentCount,
              createdAt: existing.createdAt,
              updatedAt: DateTime.now(),
            ),
          );
    } catch (_) {
      throw const BatchFailure('Could not save changes. Please try again.');
    }
  }

  Future<void> setActive(Batch existing, bool active) async {
    try {
      await _ref.read(batchRepositoryProvider).updateFields(existing.batchId, {
        'active': active,
        'updatedAt': Timestamp.now(),
      });
    } catch (_) {
      throw const BatchFailure('Could not update the batch. Please try again.');
    }
  }

  String? _blankToNull(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();
}
