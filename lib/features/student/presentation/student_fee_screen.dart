import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/application/auth_providers.dart';
import '../data/payment.dart';
import '../data/student_profile.dart';
import '../data/student_repository.dart';

/// A student/parent's own fee summary + payment history - view only, no
/// editing (matches "Student/Parent is view-only for these academic/fee
/// records").
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
                  final studentsAsync = ref.watch(allStudentsProvider);
                  return studentsAsync.when(
                    loading: () => const LoadingView(),
                    error: (error, stackTrace) => ErrorView(message: 'Could not load your profile.\n$error'),
                    data: (students) {
                      final self = students.where((s) => s.uid == account.uid).firstOrNull;
                      if (self == null) return const ErrorView(message: 'Student profile not found.');
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
    final paymentsAsync = ref.watch(studentPaymentsProvider(student.uid));

    return paymentsAsync.when(
      loading: () => const LoadingView(),
      error: (error, stackTrace) => ErrorView(message: 'Could not load payments.\n$error'),
      data: (payments) {
        final paid = totalPaid(payments);
        final remaining = due(student, payments);

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Fee summary', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  _Row('Final agreed fee', '₹${student.finalFee.toStringAsFixed(0)}'),
                  _Row('Total paid', '₹${paid.toStringAsFixed(0)}'),
                  _Row(
                    remaining < 0 ? 'Advance' : 'Due',
                    '₹${remaining.abs().toStringAsFixed(0)}',
                    color: remaining > 0 ? Theme.of(context).colorScheme.error : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Payment history', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            if (payments.isEmpty)
              const EmptyView(message: 'No payments recorded yet.')
            else
              for (final payment in payments) _PaymentTile(payment: payment),
          ],
        );
      },
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('₹${payment.amount.toStringAsFixed(0)} - ${payment.mode.label}'),
        subtitle: Text('${payment.date.toLocal()}'.split(' ').first),
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
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
