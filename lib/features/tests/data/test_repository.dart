import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../data/repositories/firestore_repository.dart';
import 'test_definition.dart';
import 'test_result.dart';

final testRepositoryProvider = Provider<FirestoreRepository<TestDefinition>>((ref) {
  return FirestoreRepository<TestDefinition>(
    firestore: ref.watch(firestoreProvider),
    collectionPath: FirestoreCollections.tests,
    fromFirestore: TestDefinition.fromMap,
    toFirestore: (test) => test.toMap(),
  );
});

/// All tests for one batch, newest first.
final batchTestsProvider = StreamProvider.family<List<TestDefinition>, String>((ref, batchId) {
  return ref.watch(testRepositoryProvider).watchAll().map(
    (tests) => tests.where((t) => t.batchId == batchId).toList()..sort((a, b) => b.date.compareTo(a.date)),
  );
});

/// A single test by id, regardless of batch - for the mark-entry and
/// student-result screens, which are reached by test id alone.
final testByIdProvider = StreamProvider.family<TestDefinition?, String>((ref, testId) {
  return ref.watch(testRepositoryProvider).watchById(testId);
});

final testResultRepositoryProvider = Provider<FirestoreRepository<TestResult>>((ref) {
  return FirestoreRepository<TestResult>(
    firestore: ref.watch(firestoreProvider),
    collectionPath: FirestoreCollections.testResults,
    fromFirestore: TestResult.fromMap,
    toFirestore: (result) => result.toMap(),
  );
});

/// Every result entered for one test - for the teacher's mark-entry grid.
final testResultsForTestProvider = StreamProvider.family<List<TestResult>, String>((ref, testId) {
  return ref.watch(testResultRepositoryProvider).watchAll().map(
    (results) => results.where((r) => r.testId == testId).toList(),
  );
});

/// One student's own result for one test - `null` until entered. Fetched
/// by its deterministic id, so a student never needs `list` permission on
/// `testResults` (see firestore.rules).
final ownTestResultProvider = StreamProvider.family<TestResult?, ({String testId, String studentUid})>((ref, args) {
  return ref
      .watch(testResultRepositoryProvider)
      .watchById(TestResult.idFor(testId: args.testId, studentUid: args.studentUid));
});
