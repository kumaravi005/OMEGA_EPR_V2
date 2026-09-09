import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/contact_actions.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/payment.dart';
import '../data/student_profile.dart';
import '../data/student_repository.dart';
import 'add_payment_dialog.dart';

class StudentProfileScreen extends ConsumerWidget {
  const StudentProfileScreen({super.key, required this.studentUid});

  final String studentUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(allStudentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () => context.push('${AppRoutes.adminStudents}/$studentUid/edit'),
          ),
        ],
      ),
      body: SafeArea(
        child: studentsAsync.when(
          loading: () => const LoadingView(),
          error: (error, stackTrace) => ErrorView(message: 'Could not load student.\n$error'),
          data: (students) {
            final student = students.where((s) => s.uid == studentUid).firstOrNull;
            if (student == null) return const ErrorView(message: 'Student not found.');
            return _ProfileBody(student: student);
          },
        ),
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.student});

  final StudentProfile student;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(studentPaymentsProvider(student.uid));

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(student.name, style: Theme.of(context).textTheme.headlineMedium),
            Text(
              student.active ? 'Active' : 'Inactive',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: student.active ? null : Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Call',
                    icon: Icons.call_outlined,
                    onPressed: () => callNumber(student.primaryMobile),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: 'WhatsApp',
                    icon: Icons.chat_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => openWhatsApp(student.primaryMobile),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Personal details', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(label: "Father's name", value: student.fatherName),
                  _InfoRow(label: 'Date of birth', value: '${student.dateOfBirth.toLocal()}'.split(' ').first),
                  _InfoRow(label: 'Gender', value: _genderLabel(student.gender.name)),
                  _InfoRow(label: 'Address', value: student.address),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Academic details', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(label: 'Class', value: student.className),
                  _InfoRow(label: 'Board', value: student.board),
                  _InfoRow(label: 'Academic session', value: student.academicSession),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Contact', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(label: 'Primary mobile', value: student.primaryMobile),
                  if (student.secondaryMobile != null && student.secondaryMobile!.isNotEmpty)
                    _InfoRow(label: 'Secondary mobile', value: student.secondaryMobile!),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            paymentsAsync.when(
              loading: () => const AppCard(child: LoadingView()),
              error: (error, stackTrace) => AppCard(child: ErrorView(message: 'Could not load payments.\n$error')),
              data: (payments) => _FeeSummaryCard(student: student, payments: payments),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(child: Text('Payment history', style: Theme.of(context).textTheme.titleLarge)),
                TextButton.icon(
                  onPressed: () => showAddPaymentDialog(context, studentUid: student.uid),
                  icon: const Icon(Icons.add),
                  label: const Text('Record payment'),
                ),
              ],
            ),
            paymentsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (error, stackTrace) => const SizedBox.shrink(),
              data: (payments) {
                if (payments.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: EmptyView(message: 'No payments recorded yet.'),
                  );
                }
                return Column(children: [for (final payment in payments) _PaymentTile(payment: payment)]);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _genderLabel(String value) {
    switch (value) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      default:
        return 'Other';
    }
  }
}

class _FeeSummaryCard extends StatelessWidget {
  const _FeeSummaryCard({required this.student, required this.payments});

  final StudentProfile student;
  final List<Payment> payments;

  @override
  Widget build(BuildContext context) {
    final paid = totalPaid(payments);
    final remaining = due(student, payments);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Fee summary', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(label: 'Standard fee', value: '₹${student.standardFee.toStringAsFixed(0)}'),
          _InfoRow(label: 'Final agreed fee', value: '₹${student.finalFee.toStringAsFixed(0)}'),
          if (student.discount != 0)
            _InfoRow(label: 'Discount / adjustment', value: '₹${student.discount.toStringAsFixed(0)}'),
          if (student.feeReason != null && student.feeReason!.isNotEmpty)
            _InfoRow(label: 'Reason', value: student.feeReason!),
          _InfoRow(label: 'Payment plan', value: student.paymentPlan.label),
          const Divider(height: AppSpacing.lg),
          _InfoRow(label: 'Total paid', value: '₹${paid.toStringAsFixed(0)}'),
          _InfoRow(
            label: remaining < 0 ? 'Advance' : 'Due',
            value: '₹${remaining.abs().toStringAsFixed(0)}',
            valueColor: remaining > 0 ? Theme.of(context).colorScheme.error : null,
          ),
        ],
      ),
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
        subtitle: Text(
          '${payment.date.toLocal()}'.split(' ').first + (payment.remark != null ? ' - ${payment.remark}' : ''),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}
