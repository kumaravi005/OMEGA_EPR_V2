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
final allBatchesProvider = StreamProvider<List<Batch>>((ref) {
  return ref
      .watch(batchRepositoryProvider)
      .watchAll()
      .map(
        (batches) => batches.toList()..sort((a, b) => a.name.compareTo(b.name)),
      );
});
