import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../student/data/student_admission.dart';
import '../../student/data/student_profile.dart';
import '../../student/data/student_repository.dart';
import 'fee_calculator.dart';
import 'fee_payment_repository.dart';

/// One student's fee position, combined from their active admission, the
/// new `feePayments` ledger, and any legacy `students/{uid}/payments`
/// history (Set 19) - the single row shape both `FeeManagementScreen`
/// (admin's list) and its filters are built from.
class StudentFeeSummary {
  const StudentFeeSummary({
    required this.student,
    required this.admission,
    required this.totalPaid,
    required this.balanceDue,
    required this.status,
  });

  final StudentProfile student;

  /// `null` when the student has no active admission/fee agreement to
  /// speak of (shouldn't normally happen for an active student, but this
  /// project never assumes it - see `StudentAdmission`).
  final StudentAdmission? admission;
  final double totalPaid;
  final double balanceDue;
  final FeeStatus? status;
}

/// Every student's [StudentFeeSummary], admin-only - powers
/// `FeeManagementScreen`'s list, search, and class/batch/session/board/
/// status filters. Deliberately a plain computed [Provider] (not a
/// [StreamProvider]) that watches [allStudentsProvider] and
/// [allFeePaymentsProvider] once each, plus each student's own
/// [studentAdmissionsProvider]/[studentPaymentsProvider] (the same
/// per-student "each row watches its own small provider" pattern the
/// pre-Set-19 `FeeDuesScreen` already used, just centralized here so the
/// status FILTER - not just the display - can see every student's
/// computed status) - correct at this project's ~200-student scale,
/// per Set 19 section 10's explicit "correctness over premature
/// optimization".
final allStudentFeeSummariesProvider = Provider<AsyncValue<List<StudentFeeSummary>>>((ref) {
  final studentsAsync = ref.watch(allStudentsProvider);
  final feePaymentsAsync = ref.watch(allFeePaymentsProvider);

  if (studentsAsync.isLoading || feePaymentsAsync.isLoading) {
    return const AsyncValue.loading();
  }
  if (studentsAsync.hasError) {
    return AsyncValue.error(studentsAsync.error!, studentsAsync.stackTrace ?? StackTrace.current);
  }
  if (feePaymentsAsync.hasError) {
    return AsyncValue.error(feePaymentsAsync.error!, feePaymentsAsync.stackTrace ?? StackTrace.current);
  }

  final students = studentsAsync.valueOrNull ?? const [];
  final allFeePayments = feePaymentsAsync.valueOrNull ?? const [];

  final rows = <StudentFeeSummary>[];
  for (final student in students) {
    final admissionsAsync = ref.watch(studentAdmissionsProvider(student.uid));
    final legacyAsync = ref.watch(studentPaymentsProvider(student.uid));
    if (admissionsAsync.isLoading || legacyAsync.isLoading) {
      return const AsyncValue.loading();
    }

    final admission = (admissionsAsync.valueOrNull ?? const [])
        .where((a) => a.active)
        .firstOrNull;
    final legacyPayments = legacyAsync.valueOrNull ?? const [];
    final feePayments = allFeePayments.where((p) => p.studentId == student.uid).toList();
    final totalPaid = combinedTotalPaid(feePayments: feePayments, legacyPayments: legacyPayments);

    if (admission == null) {
      rows.add(
        StudentFeeSummary(
          student: student,
          admission: null,
          totalPaid: totalPaid,
          balanceDue: 0,
          status: null,
        ),
      );
      continue;
    }

    final installmentRows = computeInstallmentRows(
      installments: admission.installments,
      payments: feePayments,
      now: DateTime.now(),
    );
    rows.add(
      StudentFeeSummary(
        student: student,
        admission: admission,
        totalPaid: totalPaid,
        balanceDue: admission.finalFee - totalPaid,
        status: computeFeeStatus(
          finalFee: admission.finalFee,
          totalPaid: totalPaid,
          installmentRows: installmentRows,
        ),
      ),
    );
  }
  return AsyncValue.data(rows);
});
