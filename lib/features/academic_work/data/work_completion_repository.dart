import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../data/repositories/firestore_repository.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/data/user_account.dart';
import '../../student/data/student_repository.dart';
import 'academic_work.dart';
import 'academic_work_repository.dart';
import 'work_completion.dart';

final workCompletionRepositoryProvider =
    Provider<FirestoreRepository<WorkCompletion>>((ref) {
      return FirestoreRepository<WorkCompletion>(
        firestore: ref.watch(firestoreProvider),
        collectionPath: FirestoreCollections.workCompletions,
        fromFirestore: WorkCompletion.fromMap,
        toFirestore: (completion) => completion.toMap(),
      );
    });

/// Every completion record - admin/teacher only (the `list` rule's
/// `isAdmin()`/`isTeacher()` branches have no per-document dependency, so
/// an unconstrained scan is allowed). Used for the per-item summaries on
/// the homework list, grouped client-side.
final allWorkCompletionsProvider = StreamProvider<List<WorkCompletion>>((ref) {
  return ref.watch(workCompletionRepositoryProvider).watchAll();
});

/// One piece of work's completion records - admin/teacher only.
final workCompletionsForWorkProvider =
    StreamProvider.family<List<WorkCompletion>, String>((ref, workId) {
      return ref
          .watch(workCompletionRepositoryProvider)
          .watchWhere((query) => query.where('workId', isEqualTo: workId));
    });

/// The signed-in student's OWN completion records. Constrained by
/// `studentUid`, which is exactly what the student branch of the `list`
/// rule (`isSelf(resource.data.studentUid)`) needs to be provable - an
/// unconstrained scan would be rejected (see docs/database-
/// architecture.md's "Firestore query-shape requirement"). Empty for
/// every other role.
final myWorkCompletionsProvider = StreamProvider<List<WorkCompletion>>((ref) {
  final account = ref.watch(currentUserAccountProvider).valueOrNull;
  if (account == null || account.role != UserRole.student) {
    return Stream.value(const <WorkCompletion>[]);
  }
  return ref
      .watch(workCompletionRepositoryProvider)
      .watchWhere((query) => query.where('studentUid', isEqualTo: account.uid))
      .map(
        (items) =>
            items.toList()..sort((a, b) => b.markedAt.compareTo(a.markedAt)),
      );
});

/// A completion record together with the work it is about - the shape the
/// student popup, notifications feed and homework list all need to build
/// the message.
class WorkCompletionView {
  const WorkCompletionView({required this.completion, required this.work});

  final WorkCompletion completion;
  final AcademicWork work;
}

/// The signed-in student's completion records joined to their batch's
/// (published/closed) work, newest first. A record whose work can't be
/// found - e.g. the student has since moved batch - is left out rather
/// than shown with a made-up title.
final myWorkCompletionViewsProvider = Provider<List<WorkCompletionView>>((ref) {
  final account = ref.watch(currentUserAccountProvider).valueOrNull;
  if (account == null || account.role != UserRole.student) return const [];
  final self = ref.watch(ownStudentProfileProvider(account.uid)).valueOrNull;
  if (self == null) return const [];
  final completions =
      ref.watch(myWorkCompletionsProvider).valueOrNull ?? const [];
  final works =
      ref.watch(studentVisibleAcademicWorkProvider(self.batchId)).valueOrNull ??
      const [];
  final byId = {for (final work in works) work.workId: work};
  return [
    for (final completion in completions)
      if (byId[completion.workId] != null)
        WorkCompletionView(
          completion: completion,
          work: byId[completion.workId]!,
        ),
  ];
});
