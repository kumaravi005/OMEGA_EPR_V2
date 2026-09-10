import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../data/repositories/firestore_repository.dart';
import 'callback_request.dart';
import 'enquiry.dart';

final enquiryRepositoryProvider = Provider<FirestoreRepository<Enquiry>>((ref) {
  return FirestoreRepository<Enquiry>(
    firestore: ref.watch(firestoreProvider),
    collectionPath: FirestoreCollections.enquiries,
    fromFirestore: Enquiry.fromMap,
    toFirestore: (enquiry) => enquiry.toMap(),
  );
});

final allEnquiriesProvider = StreamProvider<List<Enquiry>>((ref) {
  return ref
      .watch(enquiryRepositoryProvider)
      .watchAll()
      .map(
        (items) =>
            items.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );
});

final callbackRequestRepositoryProvider =
    Provider<FirestoreRepository<CallbackRequest>>((ref) {
      return FirestoreRepository<CallbackRequest>(
        firestore: ref.watch(firestoreProvider),
        collectionPath: FirestoreCollections.callbackRequests,
        fromFirestore: CallbackRequest.fromMap,
        toFirestore: (request) => request.toMap(),
      );
    });

final allCallbackRequestsProvider = StreamProvider<List<CallbackRequest>>((
  ref,
) {
  return ref
      .watch(callbackRequestRepositoryProvider)
      .watchAll()
      .map(
        (items) =>
            items.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );
});
