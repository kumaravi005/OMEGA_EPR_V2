import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../data/repositories/firestore_repository.dart';
import 'homework.dart';

final homeworkRepositoryProvider = Provider<FirestoreRepository<Homework>>((
  ref,
) {
  return FirestoreRepository<Homework>(
    firestore: ref.watch(firestoreProvider),
    collectionPath: FirestoreCollections.homework,
    fromFirestore: Homework.fromMap,
    toFirestore: (homework) => homework.toMap(),
  );
});

/// All homework for one batch, newest first. Filtered server-side - a
/// student's `list` rule branch depends on `batchId` per-document, which
/// Firestore can only verify against a matching query (see
/// FirestoreRepository.watchWhere).
final batchHomeworkProvider = StreamProvider.family<List<Homework>, String>((
  ref,
  batchId,
) {
  return ref
      .watch(homeworkRepositoryProvider)
      .watchWhere((query) => query.where('batchId', isEqualTo: batchId))
      .map((items) => items.toList()..sort((a, b) => b.date.compareTo(a.date)));
});
