import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../data/repositories/firestore_repository.dart';
import 'payment.dart';
import 'student_profile.dart';

final studentRepositoryProvider = Provider<FirestoreRepository<StudentProfile>>((ref) {
  return FirestoreRepository<StudentProfile>(
    firestore: ref.watch(firestoreProvider),
    collectionPath: FirestoreCollections.students,
    fromFirestore: StudentProfile.fromMap,
    toFirestore: (student) => student.toMap(),
  );
});

final allStudentsProvider = StreamProvider<List<StudentProfile>>((ref) {
  return ref
      .watch(studentRepositoryProvider)
      .watchAll()
      .map((students) => students.toList()..sort((a, b) => a.name.compareTo(b.name)));
});

/// One student's payment history, at `students/{uid}/payments`.
final paymentRepositoryProvider = Provider.family<FirestoreRepository<Payment>, String>((ref, studentUid) {
  return FirestoreRepository<Payment>(
    firestore: ref.watch(firestoreProvider),
    collectionPath: '${FirestoreCollections.students}/$studentUid/payments',
    fromFirestore: Payment.fromMap,
    toFirestore: (payment) => payment.toMap(),
  );
});

final studentPaymentsProvider = StreamProvider.family<List<Payment>, String>((ref, studentUid) {
  return ref
      .watch(paymentRepositoryProvider(studentUid))
      .watchAll()
      .map((payments) => payments.toList()..sort((a, b) => b.date.compareTo(a.date)));
});

double totalPaid(List<Payment> payments) => payments.fold(0, (sum, payment) => sum + payment.amount);

/// Positive = still owed, negative = paid more than the final fee (an
/// advance). Use [dueLabel] to render this correctly either way.
double due(StudentProfile student, List<Payment> payments) => student.finalFee - totalPaid(payments);

/// "Due ₹500" when [due] is owed, "Advance ₹200" when overpaid, "Paid in
/// full" when exactly settled.
String dueLabel(double due) {
  if (due > 0) return 'Due ₹${due.toStringAsFixed(0)}';
  if (due < 0) return 'Advance ₹${(-due).toStringAsFixed(0)}';
  return 'Paid in full';
}
