import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    } catch (_) {
      throw const AcademicConfigFailure('Could not save. Please try again.');
    }
  }
}
