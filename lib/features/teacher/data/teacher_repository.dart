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

final allTeachersProvider = StreamProvider<List<TeacherProfile>>((ref) {
  return ref
      .watch(teacherRepositoryProvider)
      .watchAll()
      .map(
        (teachers) =>
            teachers.toList()..sort((a, b) => a.name.compareTo(b.name)),
      );
});
