import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../data/repositories/firestore_repository.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/data/user_account.dart';
import '../../student/data/student_repository.dart';
import 'notice.dart';

final noticeRepositoryProvider = Provider<FirestoreRepository<Notice>>((ref) {
  return FirestoreRepository<Notice>(
    firestore: ref.watch(firestoreProvider),
    collectionPath: FirestoreCollections.notices,
    fromFirestore: Notice.fromMap,
    toFirestore: (notice) => notice.toMap(),
  );
});

/// Every notice regardless of status, newest first - admin-only (the
/// `notices` `list` rule's `isAdmin()` branch has no per-document
/// dependency, so this unconstrained `watchAll()` is safe - see
/// docs/database-architecture.md's "Firestore query-shape requirement").
/// Powers the admin management list/search/filters, all client-side at
/// this project's scale.
final allNoticesProvider = StreamProvider<List<Notice>>((ref) {
  return ref
      .watch(noticeRepositoryProvider)
      .watchAll()
      .map((notices) => notices.toList()..sort(_byRecency));
});

final noticeByIdProvider = StreamProvider.family<Notice?, String>((
  ref,
  noticeId,
) {
  return ref.watch(noticeRepositoryProvider).watchById(noticeId);
});

/// Every notice the signed-in user is eligible to see - PUBLISHED only,
/// scoped to their own role/class/batch (Set 17 sections 11-13, 17-19).
/// Admin has no "my notices" inbox (their management list, above, already
/// shows everything including drafts) - this is only ever used by the
/// teacher/student/parent screens. Teacher and student/parent each
/// resolve to a single `targetKey whereIn [...]` query (`==` + `in` on
/// two different fields, the exact shape already proven not to need a
/// manual composite index for `academicWork`'s
/// `studentVisibleAcademicWorkProvider` - see docs/database-
/// architecture.md), never an unconstrained scan filtered client-side,
/// so `notices`' `list` rule can actually verify the non-admin branches.
final myNoticesProvider = StreamProvider<List<Notice>>((ref) {
  final account = ref.watch(currentUserAccountProvider).valueOrNull;
  if (account == null) return Stream.value(const <Notice>[]);

  final repository = ref.watch(noticeRepositoryProvider);

  if (account.role == UserRole.admin) {
    return Stream.value(const <Notice>[]);
  }

  if (account.role == UserRole.teacher) {
    return repository
        .watchWhere(
          (query) => query
              .where('targetKey', whereIn: ['all', 'teachers'])
              .where('status', isEqualTo: 'published'),
        )
        .map((notices) => notices.toList()..sort(_byRecency));
  }

  final student = ref.watch(ownStudentProfileProvider(account.uid)).valueOrNull;
  if (student == null) return Stream.value(const <Notice>[]);

  final keys = [
    'all',
    'students',
    'students:class:${student.classId}',
    'students:batch:${student.batchId}',
  ];
  return repository
      .watchWhere(
        (query) => query
            .where('targetKey', whereIn: keys)
            .where('status', isEqualTo: 'published'),
      )
      .map((notices) => notices.toList()..sort(_byRecency));
});

int _byRecency(Notice a, Notice b) {
  final aDate = a.publishedAt ?? a.createdAt;
  final bDate = b.publishedAt ?? b.createdAt;
  return bDate.compareTo(aDate);
}
