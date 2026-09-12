import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/firestore_collections.dart';
import 'firebase_providers.dart';

/// Hands out a stable, unique, ever-increasing integer per named sequence
/// (e.g. `students`, for admission numbers), backed by one small counter
/// document per sequence at `counters/{sequenceId}`.
///
/// Uses a Firestore client-side transaction (no Cloud Functions - this
/// project stays on the Spark plan) to read-then-increment atomically, so
/// two admissions submitted at nearly the same moment can never receive
/// the same number.
class SequenceService {
  SequenceService(this._firestore);

  final FirebaseFirestore _firestore;

  Future<int> next(String sequenceId) {
    final ref = _firestore
        .collection(FirestoreCollections.counters)
        .doc(sequenceId);
    return _firestore.runTransaction<int>((transaction) async {
      final snapshot = await transaction.get(ref);
      final current = (snapshot.data()?['nextNumber'] as num?)?.toInt() ?? 1;
      transaction.set(ref, {
        'nextNumber': current + 1,
        'updatedAt': Timestamp.now(),
      });
      return current;
    });
  }
}

final sequenceServiceProvider = Provider<SequenceService>(
  (ref) => SequenceService(ref.watch(firestoreProvider)),
);
