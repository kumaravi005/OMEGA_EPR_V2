import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../data/repositories/firestore_repository.dart';
import 'payment.dart';
import 'student_admission.dart';
import 'student_profile.dart';

final studentRepositoryProvider = Provider<FirestoreRepository<StudentProfile>>(
  (ref) {
    return FirestoreRepository<StudentProfile>(
      firestore: ref.watch(firestoreProvider),
      collectionPath: FirestoreCollections.students,
      fromFirestore: StudentProfile.fromMap,
      toFirestore: (student) => student.toMap(),
    );
  },
);

/// Admin/teacher only - the full roster (`students` `list` requires
/// `isAdmin() || isTeacher()`, see firestore.rules). Never use this to
/// find a signed-in STUDENT's own record - use [ownStudentProfileProvider]
/// instead, since a student has no `list` permission on this collection
/// at all, only `get` on their own document.
final allStudentsProvider = StreamProvider<List<StudentProfile>>((ref) {
  return ref
      .watch(studentRepositoryProvider)
      .watchAll()
      .map(
        (students) =>
            students.toList()..sort((a, b) => a.name.compareTo(b.name)),
      );
});

/// The signed-in student's own profile, resolved via a `get` (always
/// allowed for a student reading their own document) rather than
/// `list`ing the whole collection and filtering client-side - the latter
/// fails outright for an actual student account (see [allStudentsProvider]).
final ownStudentProfileProvider =
    StreamProvider.family<StudentProfile?, String>((ref, uid) {
      return ref.watch(studentRepositoryProvider).watchById(uid);
    });

/// One student's payment history, at `students/{uid}/payments`.
final paymentRepositoryProvider =
    Provider.family<FirestoreRepository<Payment>, String>((ref, studentUid) {
      return FirestoreRepository<Payment>(
        firestore: ref.watch(firestoreProvider),
        collectionPath: '${FirestoreCollections.students}/$studentUid/payments',
        fromFirestore: Payment.fromMap,
        toFirestore: (payment) => payment.toMap(),
      );
    });

final studentPaymentsProvider = StreamProvider.family<List<Payment>, String>((
  ref,
  studentUid,
) {
  return ref
      .watch(paymentRepositoryProvider(studentUid))
      .watchAll()
      .map(
        (payments) =>
            payments.toList()..sort((a, b) => b.date.compareTo(a.date)),
      );
});

/// One student's admission history, at `students/{uid}/admissions` - see
/// [StudentAdmission] for why this is kept separate from the student's
/// own current-snapshot fields on [StudentProfile].
final studentAdmissionRepositoryProvider =
    Provider.family<FirestoreRepository<StudentAdmission>, String>((
      ref,
      studentUid,
    ) {
      return FirestoreRepository<StudentAdmission>(
        firestore: ref.watch(firestoreProvider),
        collectionPath:
            '${FirestoreCollections.students}/$studentUid/admissions',
        fromFirestore: StudentAdmission.fromMap,
        toFirestore: (admission) => admission.toMap(),
      );
    });

/// Newest admission first - the first entry is the student's current
/// admission whenever [StudentProfile.currentAdmissionId] and this stream
/// agree (they're written together, see `StudentFormController`).
final studentAdmissionsProvider =
    StreamProvider.family<List<StudentAdmission>, String>((ref, studentUid) {
      return ref
          .watch(studentAdmissionRepositoryProvider(studentUid))
          .watchAll()
          .map(
            (admissions) => admissions.toList()
              ..sort((a, b) => b.admissionDate.compareTo(a.admissionDate)),
          );
    });

/// LEGACY (pre-Set-19) - sums only the old `students/{uid}/payments`
/// subcollection, with no concept of a reversed payment. No current
/// screen calls this; every live fee/due calculation uses
/// `fee_calculator.dart`'s `combinedTotalPaid`/`combinedBalanceDue`/
/// `computeFeeStatus` instead, which also account for the Set 19
/// `feePayments` ledger and exclude reversed entries. Kept only so
/// `test/features/student/fee_calculation_test.dart` still exercises the
/// original pre-Set-19 formula - do not call this from new code.
double totalPaid(List<Payment> payments) =>
    payments.fold(0, (sum, payment) => sum + payment.amount);

/// Positive = still owed, negative = paid more than the final fee (an
/// advance). Use [dueLabel] to render this correctly either way.
double due(StudentProfile student, List<Payment> payments) =>
    student.finalFee - totalPaid(payments);

/// "Due ₹500" when [due] is owed, "Advance ₹200" when overpaid, "Paid in
/// full" when exactly settled.
String dueLabel(double due) {
  if (due > 0) return 'Due ₹${due.toStringAsFixed(0)}';
  if (due < 0) return 'Advance ₹${(-due).toStringAsFixed(0)}';
  return 'Paid in full';
}
