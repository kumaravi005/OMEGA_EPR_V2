import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../data/repositories/firestore_repository.dart';
import 'academic_session.dart';
import 'board.dart';
import 'school_class.dart';
import 'subject.dart';

/// Repository + list providers for every academic master-data collection
/// (Set 9). Each repository is a trivial one-liner over
/// `FirestoreRepository<T>` - combined in one file rather than four
/// near-empty ones, same reasoning as
/// `features/public/data/public_content_repositories.dart`.
///
/// Every collection here uses the same "shared reference catalogue" read
/// rule as `batches` (`allow get, list: if isSignedIn()`) - a role-only
/// check with no per-document dependency, so an unconstrained
/// `watchAll()` is safe (see docs/database-architecture.md's "Firestore
/// query-shape requirement" for why that distinction matters).

final academicSessionRepositoryProvider =
    Provider<FirestoreRepository<AcademicSession>>((ref) {
      return FirestoreRepository<AcademicSession>(
        firestore: ref.watch(firestoreProvider),
        collectionPath: FirestoreCollections.academicSessions,
        fromFirestore: AcademicSession.fromMap,
        toFirestore: (session) => session.toMap(),
      );
    });

/// All sessions, newest start date first - for the admin's session list.
final allAcademicSessionsProvider = StreamProvider<List<AcademicSession>>((
  ref,
) {
  return ref
      .watch(academicSessionRepositoryProvider)
      .watchAll()
      .map(
        (sessions) =>
            sessions.toList()
              ..sort((a, b) => b.startDate.compareTo(a.startDate)),
      );
});

/// The single active session, if any - for future modules to default
/// new records to. `null` before an admin has activated one.
final activeAcademicSessionProvider = StreamProvider<AcademicSession?>((ref) {
  return ref
      .watch(academicSessionRepositoryProvider)
      .watchAll()
      .map((sessions) => sessions.where((s) => s.isActive).firstOrNull);
});

final schoolClassRepositoryProvider =
    Provider<FirestoreRepository<SchoolClass>>((ref) {
      return FirestoreRepository<SchoolClass>(
        firestore: ref.watch(firestoreProvider),
        collectionPath: FirestoreCollections.classes,
        fromFirestore: SchoolClass.fromMap,
        toFirestore: (schoolClass) => schoolClass.toMap(),
      );
    });

/// All classes, in display order - for the admin's class list.
final allSchoolClassesProvider = StreamProvider<List<SchoolClass>>((ref) {
  return ref
      .watch(schoolClassRepositoryProvider)
      .watchAll()
      .map(
        (classes) =>
            classes.toList()
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
      );
});

/// Active classes only - for a future picker (e.g. student admission).
final activeSchoolClassesProvider = StreamProvider<List<SchoolClass>>((ref) {
  return ref
      .watch(schoolClassRepositoryProvider)
      .watchAll()
      .map(
        (classes) =>
            classes.where((c) => c.active).toList()
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
      );
});

final boardRepositoryProvider = Provider<FirestoreRepository<Board>>((ref) {
  return FirestoreRepository<Board>(
    firestore: ref.watch(firestoreProvider),
    collectionPath: FirestoreCollections.boards,
    fromFirestore: Board.fromMap,
    toFirestore: (board) => board.toMap(),
  );
});

/// All boards - for the admin's board list.
final allBoardsProvider = StreamProvider<List<Board>>((ref) {
  return ref
      .watch(boardRepositoryProvider)
      .watchAll()
      .map(
        (boards) => boards.toList()..sort((a, b) => a.name.compareTo(b.name)),
      );
});

/// Active boards only - for a future picker (e.g. student admission).
final activeBoardsProvider = StreamProvider<List<Board>>((ref) {
  return ref
      .watch(boardRepositoryProvider)
      .watchAll()
      .map(
        (boards) =>
            boards.where((b) => b.active).toList()
              ..sort((a, b) => a.name.compareTo(b.name)),
      );
});

final subjectRepositoryProvider = Provider<FirestoreRepository<Subject>>((ref) {
  return FirestoreRepository<Subject>(
    firestore: ref.watch(firestoreProvider),
    collectionPath: FirestoreCollections.subjects,
    fromFirestore: Subject.fromMap,
    toFirestore: (subject) => subject.toMap(),
  );
});

/// All subjects - for the admin's subject list and the class-subject
/// picker.
final allSubjectsProvider = StreamProvider<List<Subject>>((ref) {
  return ref
      .watch(subjectRepositoryProvider)
      .watchAll()
      .map(
        (subjects) =>
            subjects.toList()..sort((a, b) => a.name.compareTo(b.name)),
      );
});

/// Active subjects only - for a future picker (e.g. homework/test
/// subject dropdown, once those modules are wired to read this).
final activeSubjectsProvider = StreamProvider<List<Subject>>((ref) {
  return ref
      .watch(subjectRepositoryProvider)
      .watchAll()
      .map(
        (subjects) =>
            subjects.where((s) => s.active).toList()
              ..sort((a, b) => a.name.compareTo(b.name)),
      );
});
