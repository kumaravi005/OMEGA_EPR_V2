import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../data/repositories/firestore_repository.dart';
import 'assignment.dart';

final assignmentRepositoryProvider = Provider<FirestoreRepository<Assignment>>((
  ref,
) {
  return FirestoreRepository<Assignment>(
    firestore: ref.watch(firestoreProvider),
    collectionPath: FirestoreCollections.assignments,
    fromFirestore: Assignment.fromMap,
    toFirestore: (assignment) => assignment.toMap(),
  );
});

/// All assignments for one batch, newest first. Filtered server-side -
/// see homework_repository.dart's `batchHomeworkProvider` doc comment;
/// the same reasoning applies here.
final batchAssignmentsProvider =
    StreamProvider.family<List<Assignment>, String>((ref, batchId) {
      return ref
          .watch(assignmentRepositoryProvider)
          .watchWhere((query) => query.where('batchId', isEqualTo: batchId))
          .map(
            (items) =>
                items.toList()
                  ..sort((a, b) => b.assignedDate.compareTo(a.assignedDate)),
          );
    });
