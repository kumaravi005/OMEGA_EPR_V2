import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../data/repositories/firestore_repository.dart';
import 'batch.dart';

final batchRepositoryProvider = Provider<FirestoreRepository<Batch>>((ref) {
  return FirestoreRepository<Batch>(
    firestore: ref.watch(firestoreProvider),
    collectionPath: FirestoreCollections.batches,
    fromFirestore: Batch.fromMap,
    toFirestore: (batch) => batch.toMap(),
  );
});

/// Active batches only - for pickers (student admission) where a retired
/// batch shouldn't be selectable for new admissions.
final activeBatchesProvider = StreamProvider<List<Batch>>((ref) {
  return ref
      .watch(batchRepositoryProvider)
      .watchAll()
      .map(
        (batches) =>
            batches.where((batch) => batch.active).toList()
              ..sort((a, b) => a.name.compareTo(b.name)),
      );
});

/// All batches, including inactive ones - for the admin's batch list.
/// Read rule is `isSignedIn()` only (no per-document dependency), so an
/// unconstrained `watchAll()` is safe (see docs/database-architecture.md's
/// "Firestore query-shape requirement") - every filter the batch list
/// screen offers (session/class/board/status/search) is applied
/// client-side on this same stream, not as separate Firestore queries,
/// which keeps this at zero composite indexes.
final allBatchesProvider = StreamProvider<List<Batch>>((ref) {
  return ref
      .watch(batchRepositoryProvider)
      .watchAll()
      .map(
        (batches) => batches.toList()..sort((a, b) => a.name.compareTo(b.name)),
      );
});

/// Active batches for one class - the reusable lookup a future Student
/// Admission "Class -> Batch" picker needs (see docs/architecture.md's
/// Set 10 section). Derived client-side from [activeBatchesProvider],
/// not a new Firestore query.
final activeBatchesForClassProvider = Provider.family<List<Batch>, String>((
  ref,
  classId,
) {
  final batches =
      ref.watch(activeBatchesProvider).valueOrNull ?? const <Batch>[];
  return batches.where((batch) => batch.classId == classId).toList();
});
