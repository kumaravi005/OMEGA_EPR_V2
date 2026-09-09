import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../data/repositories/firestore_repository.dart';
import 'user_account.dart';

final userAccountRepositoryProvider = Provider<FirestoreRepository<UserAccount>>((ref) {
  return FirestoreRepository<UserAccount>(
    firestore: ref.watch(firestoreProvider),
    collectionPath: FirestoreCollections.users,
    fromFirestore: UserAccount.fromMap,
    toFirestore: (account) => account.toMap(),
  );
});
