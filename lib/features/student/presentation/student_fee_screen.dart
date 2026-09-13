import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/application/auth_providers.dart';
import '../../fees/data/fee_calculator.dart';
import '../../fees/data/fee_payment.dart';
import '../../fees/data/fee_payment_repository.dart';
import '../data/payment.dart';
import '../data/student_admission.dart';
import '../data/student_profile.dart';
import '../data/student_repository.dart';

/// A student/parent's own fee summary, installment schedule, and payment
/// history (Set 19 section 15) - view only, no editing. A parent sees
/// exactly what the associated student account sees, since this project
/// has no separate parent login (the same account/session, unchanged
/// since Set 17).
class StudentFeeScreen extends ConsumerWidget {
  const StudentFeeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(currentUserAccountProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Fees')),
      body: SafeArea(
        child: account == null
            ? const LoadingView()
            : Consumer(
                builder: (context, ref, _) {
                  final selfAsync = ref.watch(
                    ownStudentProfileProvider(account.uid),
                  );
                  return selfAsync.when(
                    loading: () => const LoadingView(),
                    error: (error, stackTrace) => ErrorView(
                      message: 'Could not load your profile.\n$error',
                    ),
                    data: (self) {
                      if (self == null) {
                        return const ErrorView(
                          message: 'Student profile not found.',
                        );
                      }
                      return _FeeBody(student: self);
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _FeeBody extends ConsumerWidget {
  const _FeeBody({required this.student});

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
      return ErrorView(message: 'Could not load your fee agreement.\n${admissionsAsync.error}');
    }
    if (feePaymentsAsync.hasError) {
      return ErrorView(message: 'Could not load payments.\n${feePaymentsAsync.error}');
    }

    final admission = (admissionsAsync.valueOrNull ?? const <StudentAdmission>[])
        .where((a) => a.active)
        .firstOrNull;
    final feePayments = feePaymentsAsync.valueOrNull ?? const <FeePayment>[];
    final legacyPayments = legacyPaymentsAsync.valueOrNull ?? const <Payment>[];

    if (admission == null) {
      return const ErrorView(message: 'No fee agreement found on your record.');
    }

    final totalPaid = combinedTotalPaid(feePayments: feePayments, legacyPayments: legacyPayments);
    final balanceDue = admission.finalFee - totalPaid;
    final installmentRows = computeInstallmentRows(
      installments: admission.installments,
      payments: feePayments,
      now: DateTime.now(),
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fee summary', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              _Row('Standard fee', '₹${admission.standardFee.toStringAsFixed(0)}'),
              if (admission.discountAmount != 0)
                _Row('Discount', '₹${admission.discountAmount.toStringAsFixed(0)}'),
              _Row('Final fee', '₹${admission.finalFee.toStringAsFixed(0)}'),
              _Row('Total paid', '₹${totalPaid.toStringAsFixed(0)}'),
              _Row(
                balanceDue < 0 ? 'Advance' : 'Balance due',
                '₹${balanceDue.abs().toStringAsFixed(0)}',
                color: balanceDue > 0 ? Theme.of(context).colorScheme.error : null,
              ),
            ],
          ),
        ),
        if (admission.installments.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text('Installments', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          for (final row in installmentRows) _InstallmentTile(row: row),
        ],
        const SizedBox(height: AppSpacing.md),
        Text('Payment history', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        if (feePayments.isEmpty && legacyPayments.isEmpty)
          const EmptyView(message: 'No payments recorded yet.')
        else ...[
          for (final payment in feePayments) _FeePaymentTile(payment: payment),
          for (final payment in legacyPayments) _LegacyPaymentTile(payment: payment),
        ],
      ],
    );
  }
}

class _InstallmentTile extends StatelessWidget {
  const _InstallmentTile({required this.row});

  final InstallmentRow row;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(row.item.label),
        subtitle: Text(
          '₹${row.item.amount.toStringAsFixed(0)} - due ${dateKey(row.item.dueDate)}',
        ),
        trailing: Chip(
          label: Text(row.status.label),
          labelStyle: TextStyle(
            color: row.status == InstallmentDisplayStatus.overdue
                ? Theme.of(context).colorScheme.error
                : null,
          ),
        ),
      ),
    );
  }
}

class _FeePaymentTile extends StatelessWidget {
  const _FeePaymentTile({required this.payment});

  final FeePayment payment;

  @override
  Widget build(BuildContext context) {
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
            if (payment.isReversed) 'Reversed',
          ].join(' · '),
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

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
