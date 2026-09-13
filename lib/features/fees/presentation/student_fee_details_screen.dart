import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../student/data/payment.dart';
import '../../student/data/student_admission.dart';
import '../../student/data/student_profile.dart';
import '../../student/data/student_repository.dart';
import '../data/fee_calculator.dart';
import '../data/fee_payment.dart';
import '../data/fee_payment_repository.dart';
import 'record_payment_dialog.dart';
import 'reverse_payment_dialog.dart';

/// Admin's fee record for one student (Set 19 section 18): Student
/// Information / Academic Information / Current Fee Agreement /
/// Installment Schedule / Payment Summary / Payment History, plus
/// Record Payment and Reverse Payment actions.
class StudentFeeDetailsScreen extends ConsumerWidget {
  const StudentFeeDetailsScreen({super.key, required this.studentUid});

  final String studentUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(allStudentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Student fees')),
      body: SafeArea(
        child: studentsAsync.when(
          loading: () => const LoadingView(),
          error: (error, stackTrace) =>
              ErrorView(message: 'Could not load student.\n$error'),
          data: (students) {
            final student = students.where((s) => s.uid == studentUid).firstOrNull;
            if (student == null) {
              return const ErrorView(message: 'Student not found.');
            }
            return _Body(student: student);
          },
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.student});

  final StudentProfile student;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admissionsAsync = ref.watch(studentAdmissionsProvider(student.uid));
    final feePaymentsAsync = ref.watch(studentFeePaymentsProvider(student.uid));
    final legacyPaymentsAsync = ref.watch(studentPaymentsProvider(student.uid));

    if (admissionsAsync.isLoading || feePaymentsAsync.isLoading || legacyPaymentsAsync.isLoading) {
      return const LoadingView();
    }
    if (admissionsAsync.hasError) {
      return ErrorView(message: 'Could not load admission history.\n${admissionsAsync.error}');
    }
    if (feePaymentsAsync.hasError) {
      return ErrorView(message: 'Could not load payments.\n${feePaymentsAsync.error}');
    }

    final admissions = admissionsAsync.valueOrNull ?? const <StudentAdmission>[];
    final admission = admissions.where((a) => a.active).firstOrNull;
    final feePayments = feePaymentsAsync.valueOrNull ?? const <FeePayment>[];
    final legacyPayments = legacyPaymentsAsync.valueOrNull ?? const <Payment>[];

    if (admission == null) {
      return const ErrorView(
        message: 'This student has no active admission/fee agreement.',
      );
    }

    final totalPaid = combinedTotalPaid(feePayments: feePayments, legacyPayments: legacyPayments);
    final totalReversed = totalReversedFeePaymentAmount(feePayments);
    final balanceDue = admission.finalFee - totalPaid;
    final installmentRows = computeInstallmentRows(
      installments: admission.installments,
      payments: feePayments,
      now: DateTime.now(),
    );
    final status = computeFeeStatus(
      finalFee: admission.finalFee,
      totalPaid: totalPaid,
      installmentRows: installmentRows,
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(student.name, style: Theme.of(context).textTheme.headlineSmall),
                ),
                Chip(label: Text(status.label)),
              ],
            ),
            if (student.admissionNumber.isNotEmpty)
              Text('Admission no. ${student.admissionNumber}'),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Academic information', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow('Session', student.academicSession),
                  _InfoRow('Class', student.className),
                  _InfoRow('Board', student.board),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current fee agreement', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow('Standard fee', '₹${admission.standardFee.toStringAsFixed(0)}'),
                  _InfoRow('Discount', '₹${admission.discountAmount.toStringAsFixed(0)}'),
                  _InfoRow('Final fee', '₹${admission.finalFee.toStringAsFixed(0)}'),
                  if (admission.feeReason != null && admission.feeReason!.isNotEmpty)
                    _InfoRow('Remark', admission.feeReason!),
                  _InfoRow('Payment plan', admission.paymentPlan.label),
                ],
              ),
            ),
            if (admission.installments.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Installment schedule', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.sm),
                    for (final row in installmentRows) _InstallmentTile(row: row),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Payment summary', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow('Total paid', '₹${totalPaid.toStringAsFixed(0)}'),
                  if (totalReversed > 0)
                    _InfoRow('Total reversed', '₹${totalReversed.toStringAsFixed(0)}'),
                  _InfoRow(
                    balanceDue < 0 ? 'Advance' : 'Balance due',
                    '₹${balanceDue.abs().toStringAsFixed(0)}',
                    color: balanceDue > 0 ? Theme.of(context).colorScheme.error : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Record payment',
              icon: Icons.add,
              onPressed: balanceDue <= 0.01
                  ? null
                  : () => showRecordPaymentDialog(
                      context,
                      student: student,
                      admission: admission,
                      currentTotalPaid: totalPaid,
                    ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Payment history', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            if (feePayments.isEmpty && legacyPayments.isEmpty)
              const EmptyView(message: 'No payments recorded yet.')
            else ...[
              for (final payment in feePayments) _FeePaymentTile(payment: payment),
              if (legacyPayments.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Earlier payments (recorded before this system)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                for (final payment in legacyPayments) _LegacyPaymentTile(payment: payment),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _InstallmentTile extends StatelessWidget {
  const _InstallmentTile({required this.row});

  final InstallmentRow row;

  @override
  Widget build(BuildContext context) {
    final color = switch (row.status) {
      InstallmentDisplayStatus.paid => null,
      InstallmentDisplayStatus.partiallyPaid => Theme.of(context).colorScheme.primary,
      InstallmentDisplayStatus.due => null,
      InstallmentDisplayStatus.overdue => Theme.of(context).colorScheme.error,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.item.label),
                Text(
                  '₹${row.item.amount.toStringAsFixed(0)} - due ${dateKey(row.item.dueDate)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Chip(
            label: Text(row.status.label),
            labelStyle: TextStyle(color: color),
          ),
        ],
      ),
    );
  }
}

class _FeePaymentTile extends ConsumerWidget {
  const _FeePaymentTile({required this.payment});

  final FeePayment payment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        title: Text(
          '${payment.paymentNumber} - ₹${payment.amount.toStringAsFixed(0)} (${payment.mode.label})',
          style: payment.isReversed
              ? const TextStyle(decoration: TextDecoration.lineThrough)
              : null,
        ),
        subtitle: Text(
          [
            dateKey(payment.paymentDate),
            if (payment.referenceNumber != null) 'Ref: ${payment.referenceNumber}',
            if (payment.installmentLabel != null) 'For: ${payment.installmentLabel}',
            if (payment.isReversed) 'Reversed: ${payment.reversalReason ?? ''}',
          ].join(' · '),
        ),
        trailing: payment.isReversed
            ? const Chip(label: Text('Reversed'))
            : TextButton(
                onPressed: () => showReversePaymentDialog(context, payment),
                child: const Text('Reverse'),
              ),
      ),
    );
  }
}

class _LegacyPaymentTile extends StatelessWidget {
  const _LegacyPaymentTile({required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('₹${payment.amount.toStringAsFixed(0)} (${payment.mode.label})'),
        subtitle: Text(dateKey(payment.date)),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
