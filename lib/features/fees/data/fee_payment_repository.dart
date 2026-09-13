import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../data/repositories/firestore_repository.dart';
import 'fee_payment.dart';

final feePaymentRepositoryProvider = Provider<FirestoreRepository<FeePayment>>(
  (ref) {
    return FirestoreRepository<FeePayment>(
      firestore: ref.watch(firestoreProvider),
      collectionPath: FirestoreCollections.feePayments,
      fromFirestore: FeePayment.fromMap,
      toFirestore: (payment) => payment.toMap(),
    );
  },
);

/// Every fee payment across every student, newest first - admin-only (the
/// `feePayments` `list` rule's `isAdmin()` branch has no per-document
/// dependency, so this unconstrained `watchAll()` is safe - see
/// docs/database-architecture.md's "Firestore query-shape requirement").
/// Powers the admin Fee Management list, which computes each student's
/// paid/due totals client-side from this one stream rather than issuing
/// 200 separate per-student queries.
final allFeePaymentsProvider = StreamProvider<List<FeePayment>>((ref) {
  return ref
      .watch(feePaymentRepositoryProvider)
      .watchAll()
      .map((payments) => payments.toList()..sort(_byRecency));
});

/// One student's own fee payments - scoped server-side by `studentId`
/// (a single equality filter, matching `feePayments`' `list` rule's
/// student/parent branch exactly - see docs/database-architecture.md's
/// "Firestore query-shape requirement"). Used by the student/parent fee
/// screen and by the admin's student fee details screen alike (admin's
/// own `isAdmin()` branch is role-only, so this constrained query is
/// still safe for them too).
final studentFeePaymentsProvider =
    StreamProvider.family<List<FeePayment>, String>((ref, studentId) {
      return ref
          .watch(feePaymentRepositoryProvider)
          .watchWhere(
            (query) => query.where('studentId', isEqualTo: studentId),
          )
          .map((payments) => payments.toList()..sort(_byRecency));
    });

int _byRecency(FeePayment a, FeePayment b) => b.paymentDate.compareTo(a.paymentDate);
