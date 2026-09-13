import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../data/repositories/firestore_repository.dart';
import 'test_definition.dart';
import 'test_result.dart';

final testRepositoryProvider = Provider<FirestoreRepository<TestDefinition>>((
  ref,
) {
  return FirestoreRepository<TestDefinition>(
    firestore: ref.watch(firestoreProvider),
    collectionPath: FirestoreCollections.tests,
    fromFirestore: TestDefinition.fromMap,
    toFirestore: (test) => test.toMap(),
  );
});

/// All tests for one batch, newest first. Filtered server-side - see
/// homework_repository.dart's `batchHomeworkProvider` doc comment; the
/// same reasoning applies here.
final batchTestsProvider = StreamProvider.family<List<TestDefinition>, String>((
  ref,
  batchId,
) {
  return ref
      .watch(testRepositoryProvider)
      .watchWhere((query) => query.where('batchId', isEqualTo: batchId))
      .map((tests) => tests.toList()..sort((a, b) => b.date.compareTo(a.date)));
});

/// A single test by id, regardless of batch - for the mark-entry and
/// student-result screens, which are reached by test id alone.
final testByIdProvider = StreamProvider.family<TestDefinition?, String>((
  ref,
  testId,
) {
  return ref.watch(testRepositoryProvider).watchById(testId);
});

/// Every test, newest first - admin/teacher only (the `tests` `list`
/// rule's `isAdmin()`/`isTeacher()` branches have no per-document
/// dependency, so this unconstrained `watchAll()` is safe - see
/// docs/database-architecture.md's "Firestore query-shape requirement").
/// For the searchable/filterable test list (Set 14), which filters by
/// session/class/batch/subject/type/date-range entirely client-side
/// rather than as separate Firestore queries - the same "one stream,
/// filter in the UI" approach used throughout this project.
final allTestsProvider = StreamProvider<List<TestDefinition>>((ref) {
  return ref
      .watch(testRepositoryProvider)
      .watchAll()
      .map((tests) => tests.toList()..sort((a, b) => b.date.compareTo(a.date)));
});

final testResultRepositoryProvider = Provider<FirestoreRepository<TestResult>>((
  ref,
) {
  return FirestoreRepository<TestResult>(
    firestore: ref.watch(firestoreProvider),
    collectionPath: FirestoreCollections.testResults,
    fromFirestore: TestResult.fromMap,
    toFirestore: (result) => result.toMap(),
  );
});

/// Every result entered for one test - for the teacher's mark-entry grid.
final testResultsForTestProvider =
    StreamProvider.family<List<TestResult>, String>((ref, testId) {
      return ref
          .watch(testResultRepositoryProvider)
          .watchAll()
          .map((results) => results.where((r) => r.testId == testId).toList());
    });

/// Every test result, unfiltered - admin/teacher only (`testResults`'
/// `list` rule grants both roles unconditionally, so this unconstrained
/// `watchAll()` is safe - see docs/database-architecture.md's "Firestore
/// query-shape requirement"). For the combined-result screen (Set 15),
/// which needs results across SEVERAL tests at once and filters by
/// `testId` membership client-side - a `StreamProvider.family` keyed by
/// a `List<String>` would be unsound (lists don't have value equality,
/// so a fresh list literal on every rebuild would never hit the same
/// cache entry), so this is deliberately a single unconstrained stream
/// instead, exactly like [testResultsForTestProvider] but for many
/// tests instead of one.
final allTestResultsProvider = StreamProvider<List<TestResult>>((ref) {
  return ref.watch(testResultRepositoryProvider).watchAll();
});

/// One student's own result for one test - `null` until entered. Fetched
/// by its deterministic id, so a student never needs `list` permission on
/// `testResults` (see firestore.rules).
final ownTestResultProvider =
    StreamProvider.family<TestResult?, ({String testId, String studentUid})>((
      ref,
      args,
    ) {
      return ref
          .watch(testResultRepositoryProvider)
          .watchById(
            TestResult.idFor(testId: args.testId, studentUid: args.studentUid),
          );
    });
