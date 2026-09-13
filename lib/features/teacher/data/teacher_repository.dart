import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../data/repositories/firestore_repository.dart';
import 'teacher_profile.dart';

final teacherRepositoryProvider = Provider<FirestoreRepository<TeacherProfile>>(
  (ref) {
    return FirestoreRepository<TeacherProfile>(
      firestore: ref.watch(firestoreProvider),
      collectionPath: FirestoreCollections.teachers,
      fromFirestore: TeacherProfile.fromMap,
      toFirestore: (teacher) => teacher.toMap(),
    );
  },
);

/// Admin's full teacher list, including inactive ones - every filter the
/// teacher list screen offers (search/subject/status) is applied
/// client-side on this one stream, matching `allStudentsProvider`/
/// `allBatchesProvider` at this project's scale (~10 teachers).
final allTeachersProvider = StreamProvider<List<TeacherProfile>>((ref) {
  return ref
      .watch(teacherRepositoryProvider)
      .watchAll()
      .map(
        (teachers) =>
            teachers.toList()..sort((a, b) => a.name.compareTo(b.name)),
      );
});

/// The signed-in teacher's own profile, resolved via a `get` (always
/// allowed for a teacher reading their own document - see
/// `teachers/{teacherId}`'s `isSelf(teacherId)` rule branch) rather than
/// `list`ing the whole collection - same reasoning as
/// [ownStudentProfileProvider] in the student feature. Set 16 uses this
/// to resolve the signed-in teacher's own `subjectIds` for the academic
/// work list's default subject filter.
final ownTeacherProfileProvider = StreamProvider.family<TeacherProfile?, String>(
  (ref, uid) => ref.watch(teacherRepositoryProvider).watchById(uid),
);

/// Active teachers only - for a future teacher-batch-subject assignment
/// picker (Set 12 spec: "an inactive teacher should not normally be
/// selectable for future assignments"). Derived client-side, not a new
/// Firestore query - same reasoning as `activeBatchesProvider`.
final activeTeachersProvider = StreamProvider<List<TeacherProfile>>((ref) {
  return ref
      .watch(teacherRepositoryProvider)
      .watchAll()
      .map(
        (teachers) =>
            teachers.where((teacher) => teacher.active).toList()
              ..sort((a, b) => a.name.compareTo(b.name)),
      );
});
