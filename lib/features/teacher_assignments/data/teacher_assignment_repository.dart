import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../data/repositories/firestore_repository.dart';
import '../../academics/data/school_class.dart';
import '../../academics/data/subject.dart';
import '../../teacher/data/teacher_profile.dart';
import 'teacher_assignment.dart';

final teacherAssignmentRepositoryProvider =
    Provider<FirestoreRepository<TeacherAssignment>>((ref) {
      return FirestoreRepository<TeacherAssignment>(
        firestore: ref.watch(firestoreProvider),
        collectionPath: FirestoreCollections.teacherAssignments,
        fromFirestore: TeacherAssignment.fromMap,
        toFirestore: (assignment) => assignment.toMap(),
      );
    });

/// Every assignment, including inactive ones - for the admin's
/// assignment list, which applies every filter (teacher/session/class/
/// batch/subject/status/search) client-side on this one stream, same
/// reasoning as `allBatchesProvider`/`allTeachersProvider` at this
/// project's scale. Safe as an unconstrained `watchAll()`: the caller
/// reaching this provider is always admin (the screen that watches it is
/// admin-only), and `teacherAssignments`' `list` rule's `isAdmin()`
/// branch has no per-document dependency (see docs/database-
/// architecture.md's "Firestore query-shape requirement").
final allTeacherAssignmentsProvider =
    StreamProvider<List<TeacherAssignment>>((ref) {
      return ref
          .watch(teacherAssignmentRepositoryProvider)
          .watchAll()
          .map(
            (assignments) => assignments.toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
          );
    });

/// One teacher's OWN assignments, newest first - what
/// `MyAssignmentsScreen` shows a signed-in teacher. Filtered server-side,
/// not `allTeacherAssignmentsProvider` + a client filter: a teacher's
/// `list` rule branch depends on `teacherId` per-document, which
/// Firestore can only verify against a query constrained by a matching
/// `.where()` (see `FirestoreRepository.watchWhere`'s doc comment - the
/// same reasoning already applied to `teacherOwnAttendanceProvider`).
final ownTeacherAssignmentsProvider =
    StreamProvider.family<List<TeacherAssignment>, String>((ref, teacherId) {
      return ref
          .watch(teacherAssignmentRepositoryProvider)
          .watchWhere((query) => query.where('teacherId', isEqualTo: teacherId))
          .map(
            (assignments) => assignments.toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
          );
    });

/// Active assignments only - derived client-side from
/// [allTeacherAssignmentsProvider], same pattern as
/// `activeBatchesProvider`/`activeTeachersProvider`.
final activeTeacherAssignmentsProvider =
    Provider<List<TeacherAssignment>>((ref) {
      final assignments =
          ref.watch(allTeacherAssignmentsProvider).valueOrNull ??
          const <TeacherAssignment>[];
      return assignments.where((a) => a.active).toList();
    });

/// One teacher's assignments, from the admin-side full list (e.g. a
/// future "assignments" section on the teacher's own profile screen) -
/// distinct from [ownTeacherAssignmentsProvider], which is the
/// self-service, rule-constrained read a signed-in teacher uses for
/// themselves. Derived client-side, not a second Firestore query.
final assignmentsForTeacherProvider =
    Provider.family<List<TeacherAssignment>, String>((ref, teacherId) {
      final assignments =
          ref.watch(allTeacherAssignmentsProvider).valueOrNull ??
          const <TeacherAssignment>[];
      return assignments.where((a) => a.teacherId == teacherId).toList();
    });

/// Every assignment for one batch (any subject/teacher) - the reusable
/// lookup a future teacher-scoped attendance/homework/test module would
/// need ("which teachers currently teach this batch, and what") per Set
/// 22 section 12-14. Derived client-side, not a new Firestore query.
final assignmentsForBatchProvider =
    Provider.family<List<TeacherAssignment>, String>((ref, batchId) {
      final assignments =
          ref.watch(allTeacherAssignmentsProvider).valueOrNull ??
          const <TeacherAssignment>[];
      return assignments.where((a) => a.batchId == batchId).toList();
    });

/// Every assignment for one subject (any teacher/batch) - the mirror of
/// [assignmentsForBatchProvider], for a future "who teaches Mathematics"
/// lookup. Derived client-side, not a new Firestore query.
final assignmentsForSubjectProvider =
    Provider.family<List<TeacherAssignment>, String>((ref, subjectId) {
      final assignments =
          ref.watch(allTeacherAssignmentsProvider).valueOrNull ??
          const <TeacherAssignment>[];
      return assignments.where((a) => a.subjectId == subjectId).toList();
    });

/// Assignments matching a session/class/batch combination (any of the
/// three may be omitted) - a plain, pure function like
/// `batchesForSessionAndClass`, so it's directly unit-testable and reusable
/// from both the admin list screen's filters and any future module.
List<TeacherAssignment> assignmentsMatching(
  List<TeacherAssignment> assignments, {
  String? teacherId,
  String? academicSessionId,
  String? classId,
  String? batchId,
  String? subjectId,
  bool? active,
}) {
  return assignments.where((a) {
    if (teacherId != null && a.teacherId != teacherId) return false;
    if (academicSessionId != null && a.academicSessionId != academicSessionId) {
      return false;
    }
    if (classId != null && a.classId != classId) return false;
    if (batchId != null && a.batchId != batchId) return false;
    if (subjectId != null && a.subjectId != subjectId) return false;
    if (active != null && a.active != active) return false;
    return true;
  }).toList();
}

/// Whether an assignment already exists (active or inactive) for this
/// exact teacher+session+batch+subject combination - the application-level
/// half of Set 22 section 6's duplicate-prevention requirement (the
/// deterministic [TeacherAssignment.idFor] id is the other half: even
/// without this check, two ACTIVE documents for the same combination can
/// never exist, since they would be the same document). Checked before
/// `TeacherAssignmentController.createAssignment` ever writes, so the
/// admin gets a clear "this assignment already exists" message instead of
/// a rule rejection.
bool isDuplicateAssignment(
  List<TeacherAssignment> assignments, {
  required String teacherId,
  required String academicSessionId,
  required String batchId,
  required String subjectId,
}) {
  final id = TeacherAssignment.idFor(
    teacherId: teacherId,
    academicSessionId: academicSessionId,
    batchId: batchId,
    subjectId: subjectId,
  );
  return assignments.any((a) => a.assignmentId == id);
}

/// Which subjects are selectable for an assignment to [teacher] in
/// [schoolClass] - the intersection of "subjects this class offers" (Set
/// 9's `SchoolClass.subjectIds`) and "subjects this teacher is capable of
/// teaching" (Set 12's `TeacherProfile.subjectIds`), per Set 22 sections
/// 3-4: subject options must come from the class's configured subjects,
/// AND must respect the teacher's capability - never free text, never
/// one without the other. A plain, pure function (like
/// `batchesForSessionAndClass`) so both the form dialog and its tests can
/// call it directly. Returns nothing until both a class and a teacher are
/// chosen.
List<Subject> subjectOptionsForAssignment({
  required SchoolClass? schoolClass,
  required TeacherProfile? teacher,
  required List<Subject> allSubjects,
}) {
  if (schoolClass == null || teacher == null) return const [];
  return allSubjects
      .where(
        (subject) =>
            schoolClass.subjectIds.contains(subject.subjectId) &&
            teacher.subjectIds.contains(subject.subjectId),
      )
      .toList();
}
