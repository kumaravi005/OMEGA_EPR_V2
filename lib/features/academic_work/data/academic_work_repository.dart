import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../data/repositories/firestore_repository.dart';
import 'academic_work.dart';

final academicWorkRepositoryProvider =
    Provider<FirestoreRepository<AcademicWork>>((ref) {
      return FirestoreRepository<AcademicWork>(
        firestore: ref.watch(firestoreProvider),
        collectionPath: FirestoreCollections.academicWork,
        fromFirestore: AcademicWork.fromMap,
        toFirestore: (work) => work.toMap(),
      );
    });

/// Every academic-work item, newest first - admin/teacher only (the
/// `academicWork` `list` rule's `isAdmin()`/`isTeacher()` branches have
/// no per-document dependency, so this unconstrained `watchAll()` is
/// safe - see docs/database-architecture.md's "Firestore query-shape
/// requirement"). The admin/teacher list screen filters by type/
/// session/class/batch/subject/status entirely client-side, matching
/// `allTestsProvider`'s established pattern at this project's scale.
final allAcademicWorkProvider = StreamProvider<List<AcademicWork>>((ref) {
  return ref
      .watch(academicWorkRepositoryProvider)
      .watchAll()
      .map((items) => items.toList()..sort((a, b) => b.dueDate.compareTo(a.dueDate)));
});

final academicWorkByIdProvider = StreamProvider.family<AcademicWork?, String>((
  ref,
  workId,
) {
  return ref.watch(academicWorkRepositoryProvider).watchById(workId);
});

/// One batch's PUBLISHED and CLOSED academic work only - never draft
/// (Set 16 spec: "draft is not visible to students/parents"). Filtered
/// server-side by BOTH `batchId` and `status`, matching the shape
/// `academicWorkUpdateIsValid`'s student `list`/`get` branch requires -
/// an unconstrained scan (or one filtered by `batchId` alone) cannot
/// satisfy a rule that also depends on `status`, exactly the "Firestore
/// query-shape requirement" lesson already documented for attendance/
/// homework/tests. Used by both the student/parent view and the
/// student-dashboard "active homework" stat.
final studentVisibleAcademicWorkProvider =
    StreamProvider.family<List<AcademicWork>, String>((ref, batchId) {
      return ref
          .watch(academicWorkRepositoryProvider)
          .watchWhere(
            (query) => query
                .where('batchId', isEqualTo: batchId)
                .where('status', whereIn: ['published', 'closed']),
          )
          .map(
            (items) => items.toList()..sort((a, b) => b.dueDate.compareTo(a.dueDate)),
          );
    });
