import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/services/firebase_providers.dart';
import '../data/academic_session.dart';
import '../data/academics_repositories.dart';
import '../data/board.dart';
import '../data/school_class.dart';
import '../data/subject.dart';

/// A clean, user-facing reason an academic-configuration admin action
/// failed.
class AcademicConfigFailure implements Exception {
  const AcademicConfigFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

final academicConfigControllerProvider = Provider<AcademicConfigController>(
  (ref) => AcademicConfigController(ref),
);

/// Admin CRUD for every academic master-data type (session, class,
/// board, subject). They share no business logic beyond "write it,
/// stamp timestamps, translate failures" - one controller instead of
/// four near-identical ones, same reasoning as
/// `PublicContentController`.
class AcademicConfigController {
  AcademicConfigController(this._ref);

  final Ref _ref;

  // ---- Academic sessions -------------------------------------------------

  Future<void> saveSession({
    AcademicSession? existing,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
  }) => _run(() async {
    final now = DateTime.now();
    final session = AcademicSession(
      sessionId: existing?.sessionId ?? '',
      name: name.trim(),
      startDate: startDate,
      endDate: endDate,
      isActive: existing?.isActive ?? false,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    final repo = _ref.read(academicSessionRepositoryProvider);
    if (existing == null) {
      await repo.add(session);
    } else {
      await repo.set(existing.sessionId, session);
    }
  });

  /// Marks [session] active and every other session inactive, in one
  /// atomic batch - see [AcademicSession]'s doc comment for why this
  /// (not a Firestore rule) is what enforces "only one active session".
  Future<void> setActiveSession(AcademicSession session) => _run(() async {
    final repo = _ref.read(academicSessionRepositoryProvider);
    final all = await repo.getAll();
    final batch = FirebaseFirestore.instance.batch();
    final now = Timestamp.now();
    for (final other in all) {
      if (other.sessionId == session.sessionId || !other.isActive) continue;
      batch.update(repo.collection.doc(other.sessionId), {
        'isActive': false,
        'updatedAt': now,
      });
    }
    batch.update(repo.collection.doc(session.sessionId), {
      'isActive': true,
      'updatedAt': now,
    });
    await batch.commit();
  });

  // ---- Classes ------------------------------------------------------------

  Future<void> saveClass({
    SchoolClass? existing,
    required String name,
    required int sortOrder,
  }) => _run(() async {
    final now = DateTime.now();
    final schoolClass = SchoolClass(
      classId: existing?.classId ?? '',
      name: name.trim(),
      sortOrder: sortOrder,
      active: existing?.active ?? true,
      subjectIds: existing?.subjectIds ?? const [],
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    final repo = _ref.read(schoolClassRepositoryProvider);
    if (existing == null) {
      await repo.add(schoolClass);
    } else {
      await repo.set(existing.classId, schoolClass);
    }
  });

  Future<void> setClassActive(SchoolClass existing, bool active) => _run(
    () => _ref.read(schoolClassRepositoryProvider).updateFields(
      existing.classId,
      {'active': active, 'updatedAt': Timestamp.now()},
    ),
  );

  Future<void> setClassSubjects(
    SchoolClass existing,
    List<String> subjectIds,
  ) => _run(
    () => _ref.read(schoolClassRepositoryProvider).updateFields(
      existing.classId,
      {'subjectIds': subjectIds, 'updatedAt': Timestamp.now()},
    ),
  );

  /// Every collection whose documents can reference a class by id -
  /// checked before [deleteClass] is allowed to proceed. Not exhaustive of
  /// every historical trace (a past `students/{uid}/admissions` snapshot
  /// isn't checked - a subcollection query would need a dedicated
  /// collection-group index), but covers every currently-operational
  /// reference, including the live `students` document itself.
  static const _classReferenceCollections = [
    FirestoreCollections.batches,
    FirestoreCollections.students,
    FirestoreCollections.tests,
    FirestoreCollections.academicWork,
    FirestoreCollections.teacherAssignments,
    FirestoreCollections.attendance,
    FirestoreCollections.feePayments,
    FirestoreCollections.notices,
    FirestoreCollections.enquiries,
  ];

  /// Whether [classId] is referenced by any real record. See
  /// [_classReferenceCollections]'s doc comment for what this does and
  /// doesn't cover.
  Future<bool> isClassInUse(String classId) async {
    final firestore = _ref.read(firestoreProvider);
    for (final collection in _classReferenceCollections) {
      final snapshot = await firestore
          .collection(collection)
          .where('classId', isEqualTo: classId)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) return true;
    }
    return false;
  }

  /// Permanently deletes [existing] - unlike every other action in this
  /// controller, this is a real hard delete (see docs/database-
  /// architecture.md's "Data safety: no delete, ever" for why that's
  /// normally disallowed). Only intended for cleaning up a class that was
  /// never actually used (e.g. created while testing) - refuses with a
  /// clear [AcademicConfigFailure] when [isClassInUse] finds any
  /// reference; prefer [setClassActive] to deactivate a class that's
  /// genuinely in use.
  Future<void> deleteClass(SchoolClass existing) => _run(() async {
    if (await isClassInUse(existing.classId)) {
      throw const AcademicConfigFailure(
        'This class is in use (by a batch, student, test, homework, '
        'attendance, fee, notice, or enquiry record) and cannot be '
        'deleted. Deactivate it instead.',
      );
    }
    await _ref.read(schoolClassRepositoryProvider).delete(existing.classId);
  });

  // ---- Boards ---------------------------------------------------------------

  Future<void> saveBoard({Board? existing, required String name}) =>
      _run(() async {
        final now = DateTime.now();
        final board = Board(
          boardId: existing?.boardId ?? '',
          name: name.trim(),
          active: existing?.active ?? true,
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
        );
        final repo = _ref.read(boardRepositoryProvider);
        if (existing == null) {
          await repo.add(board);
        } else {
          await repo.set(existing.boardId, board);
        }
      });

  Future<void> setBoardActive(Board existing, bool active) => _run(
    () => _ref.read(boardRepositoryProvider).updateFields(existing.boardId, {
      'active': active,
      'updatedAt': Timestamp.now(),
    }),
  );

  /// Every collection whose documents can reference a board by id -
  /// checked before [deleteBoard] is allowed to proceed. `boardId` is
  /// optional everywhere it appears (Batch/StudentProfile/Enquiry), unlike
  /// `classId`, so there are fewer reference points; see
  /// [_classReferenceCollections]'s doc comment for the same
  /// historical-trace caveat (a `students/{uid}/admissions` subcollection
  /// snapshot isn't checked).
  static const _boardReferenceCollections = [
    FirestoreCollections.batches,
    FirestoreCollections.students,
    FirestoreCollections.enquiries,
  ];

  /// Whether [boardId] is referenced by any real record.
  Future<bool> isBoardInUse(String boardId) async {
    final firestore = _ref.read(firestoreProvider);
    for (final collection in _boardReferenceCollections) {
      final snapshot = await firestore
          .collection(collection)
          .where('boardId', isEqualTo: boardId)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) return true;
    }
    return false;
  }

  /// Permanently deletes [existing]. See [deleteClass]'s doc comment -
  /// same reasoning and same scoped exception to the project's normal
  /// "no delete, ever" rule.
  Future<void> deleteBoard(Board existing) => _run(() async {
    if (await isBoardInUse(existing.boardId)) {
      throw const AcademicConfigFailure(
        'This board is in use (by a batch, student, or enquiry record) '
        'and cannot be deleted. Deactivate it instead.',
      );
    }
    await _ref.read(boardRepositoryProvider).delete(existing.boardId);
  });

  // ---- Subjects -----------------------------------------------------------

  Future<void> saveSubject({Subject? existing, required String name}) =>
      _run(() async {
        final now = DateTime.now();
        final subject = Subject(
          subjectId: existing?.subjectId ?? '',
          name: name.trim(),
          active: existing?.active ?? true,
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
        );
        final repo = _ref.read(subjectRepositoryProvider);
        if (existing == null) {
          await repo.add(subject);
        } else {
          await repo.set(existing.subjectId, subject);
        }
      });

  Future<void> setSubjectActive(Subject existing, bool active) => _run(
    () => _ref.read(subjectRepositoryProvider).updateFields(
      existing.subjectId,
      {'active': active, 'updatedAt': Timestamp.now()},
    ),
  );

  /// Every collection whose documents can reference a subject by id
  /// (`subjectId`), plus the two places a subject is referenced from a
  /// `subjectIds` list rather than a single field - checked before
  /// [deleteSubject] is allowed to proceed. See
  /// [_classReferenceCollections]'s doc comment for the same historical-
  /// trace caveat.
  static const _subjectReferenceCollections = [
    FirestoreCollections.tests,
    FirestoreCollections.academicWork,
    FirestoreCollections.teacherAssignments,
  ];

  /// Whether [subjectId] is referenced by any real record.
  Future<bool> isSubjectInUse(String subjectId) async {
    final firestore = _ref.read(firestoreProvider);
    for (final collection in _subjectReferenceCollections) {
      final snapshot = await firestore
          .collection(collection)
          .where('subjectId', isEqualTo: subjectId)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) return true;
    }
    final classesOfferingIt = await firestore
        .collection(FirestoreCollections.classes)
        .where('subjectIds', arrayContains: subjectId)
        .limit(1)
        .get();
    if (classesOfferingIt.docs.isNotEmpty) return true;
    final teachersCapableOfIt = await firestore
        .collection(FirestoreCollections.teachers)
        .where('subjectIds', arrayContains: subjectId)
        .limit(1)
        .get();
    return teachersCapableOfIt.docs.isNotEmpty;
  }

  /// Permanently deletes [existing]. See [deleteClass]'s doc comment -
  /// same reasoning and same scoped exception to the project's normal
  /// "no delete, ever" rule.
  Future<void> deleteSubject(Subject existing) => _run(() async {
    if (await isSubjectInUse(existing.subjectId)) {
      throw const AcademicConfigFailure(
        'This subject is in use (offered by a class, taught by a '
        'teacher, or used in a test/homework record) and cannot be '
        'deleted. Deactivate it instead.',
      );
    }
    await _ref.read(subjectRepositoryProvider).delete(existing.subjectId);
  });

  // ---- One-time default seeding --------------------------------------------

  /// Writes the institute's initial classes/boards/subjects/class-subject
  /// mapping, exactly as specified for Set 9 - Class 5-12, CBSE/BSEB/
  /// Others, and the standard subject list, with Class 5-8 offering
  /// Science and Class 9-12 offering Physics/Chemistry/Biology instead.
  ///
  /// Idempotent by design (deterministic ids, existence-checked before
  /// writing), not a silent app-launch migration: an admin explicitly
  /// triggers this from the Configuration hub, so nothing is created
  /// without them seeing it happen. Safe to run more than once - it only
  /// creates entries that don't exist yet, so it never overwrites
  /// `active`/a name/a class's subject list an admin has since edited
  /// away from these defaults.
  Future<void> seedDefaults() => _run(() async {
    final now = DateTime.now();
    final classRepo = _ref.read(schoolClassRepositoryProvider);
    final boardRepo = _ref.read(boardRepositoryProvider);
    final subjectRepo = _ref.read(subjectRepositoryProvider);

    const subjectNames = {
      'hindi': 'Hindi',
      'english': 'English',
      'sanskrit': 'Sanskrit',
      'mathematics': 'Mathematics',
      'social_science': 'Social Science',
      'history': 'History',
      'civics': 'Civics / Political Science',
      'economics': 'Economics',
      'science': 'Science',
      'physics': 'Physics',
      'chemistry': 'Chemistry',
      'biology': 'Biology',
    };

    const lowerSubjects = [
      'hindi',
      'english',
      'sanskrit',
      'mathematics',
      'social_science',
      'science',
    ];
    const upperSubjects = [
      'hindi',
      'english',
      'sanskrit',
      'mathematics',
      'history',
      'civics',
      'economics',
      'physics',
      'chemistry',
      'biology',
    ];

    final existingSubjectIds = (await subjectRepo.getAll())
        .map((s) => s.subjectId)
        .toSet();
    for (final entry in subjectNames.entries) {
      if (existingSubjectIds.contains(entry.key)) continue;
      await subjectRepo.set(
        entry.key,
        Subject(
          subjectId: entry.key,
          name: entry.value,
          active: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    final existingBoardIds = (await boardRepo.getAll())
        .map((b) => b.boardId)
        .toSet();
    for (final board in ['CBSE', 'BSEB', 'Others']) {
      final id = board.toLowerCase();
      if (existingBoardIds.contains(id)) continue;
      await boardRepo.set(
        id,
        Board(
          boardId: id,
          name: board,
          active: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    final existingClassIds = (await classRepo.getAll())
        .map((c) => c.classId)
        .toSet();
    for (var grade = 5; grade <= 12; grade++) {
      final id = 'class$grade';
      if (existingClassIds.contains(id)) continue;
      await classRepo.set(
        id,
        SchoolClass(
          classId: id,
          name: 'Class $grade',
          sortOrder: grade,
          active: true,
          subjectIds: grade <= 8 ? lowerSubjects : upperSubjects,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  });

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on AcademicConfigFailure {
      rethrow;
    } catch (_) {
      throw const AcademicConfigFailure('Could not save. Please try again.');
    }
  }
}
