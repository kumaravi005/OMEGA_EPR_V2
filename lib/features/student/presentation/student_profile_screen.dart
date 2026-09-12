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
import '../application/student_form_controller.dart';
import '../data/payment.dart';
import '../data/student_admission.dart';
import '../data/student_profile.dart';
import '../data/student_repository.dart';
import 'add_payment_dialog.dart';
import 'change_batch_dialog.dart';

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
            onPressed: () =>
                context.push('${AppRoutes.adminStudents}/$studentUid/edit'),
          ),
        ],
      ),
      body: SafeArea(
        child: studentsAsync.when(
          loading: () => const LoadingView(),
          error: (error, stackTrace) =>
              ErrorView(message: 'Could not load student.\n$error'),
          data: (students) {
            final student = students
                .where((s) => s.uid == studentUid)
                .firstOrNull;
            if (student == null) {
              return const ErrorView(message: 'Student not found.');
            }
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

  Future<void> _toggleActive(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(studentFormControllerProvider)
          .setActive(student, !student.active);
    } on StudentFormFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(studentPaymentsProvider(student.uid));
    final admissionsAsync = ref.watch(studentAdmissionsProvider(student.uid));

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PhotoAvatar(photoUrl: student.photoUrl),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      if (student.admissionNumber.isNotEmpty)
                        Text('Admission no. ${student.admissionNumber}'),
                      Text(
                        student.active ? 'Active' : 'Inactive',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(
                              color: student.active
                                  ? null
                                  : Theme.of(context).colorScheme.error,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
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
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: student.active ? 'Deactivate student' : 'Activate student',
              variant: AppButtonVariant.secondary,
              onPressed: () => _toggleActive(context, ref),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Student information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(
                    label: 'Date of birth',
                    value: '${student.dateOfBirth.toLocal()}'.split(' ').first,
                  ),
                  _InfoRow(
                    label: 'Gender',
                    value: _genderLabel(student.gender.name),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Parent & contact',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(label: "Father's name", value: student.fatherName),
                  _InfoRow(
                    label: 'Primary mobile',
                    value: student.primaryMobile,
                  ),
                  if (student.secondaryMobile != null &&
                      student.secondaryMobile!.isNotEmpty)
                    _InfoRow(
                      label: 'Secondary mobile',
                      value: student.secondaryMobile!,
                    ),
                  _InfoRow(label: 'Address', value: student.address),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Academic information',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            showChangeBatchDialog(context, student: student),
                        child: const Text('Change batch'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(label: 'Class', value: student.className),
                  _InfoRow(label: 'Board', value: student.board),
                  _InfoRow(
                    label: 'Academic session',
                    value: student.academicSession,
                  ),
                  _InfoRow(
                    label: 'Admission date',
                    value: '${student.admissionDate.toLocal()}'
                        .split(' ')
                        .first,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            paymentsAsync.when(
              loading: () => const AppCard(child: LoadingView()),
              error: (error, stackTrace) => AppCard(
                child: ErrorView(message: 'Could not load payments.\n$error'),
              ),
              data: (payments) => _FeeSummaryCard(
                student: student,
                payments: payments,
                admissions: admissionsAsync.valueOrNull ?? const [],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(label: 'Account ID', value: student.accountId),
                  _InfoRow(
                    label: 'Account status',
                    value: student.active ? 'Active' : 'Inactive',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Payment history',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => showAddPaymentDialog(
                    context,
                    studentUid: student.uid,
                    batchId: student.batchId,
                  ),
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
                return Column(
                  children: [
                    for (final payment in payments)
                      _PaymentTile(payment: payment),
                  ],
                );
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

class _PhotoAvatar extends StatelessWidget {
  const _PhotoAvatar({required this.photoUrl});

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    if (photoUrl == null || photoUrl!.isEmpty) {
      return const CircleAvatar(radius: 32, child: Icon(Icons.person));
    }
    return CircleAvatar(
      radius: 32,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      backgroundImage: NetworkImage(photoUrl!),
      onBackgroundImageError: (_, _) {},
    );
  }
}

class _FeeSummaryCard extends StatelessWidget {
  const _FeeSummaryCard({
    required this.student,
    required this.payments,
    required this.admissions,
  });

  final StudentProfile student;
  final List<Payment> payments;
  final List<StudentAdmission> admissions;

  @override
  Widget build(BuildContext context) {
    final paid = totalPaid(payments);
    final remaining = due(student, payments);
    final currentAdmission = admissions
        .where((a) => a.admissionId == student.currentAdmissionId)
        .firstOrNull;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Fee agreement', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(
            label: 'Standard fee',
            value: '₹${student.standardFee.toStringAsFixed(0)}',
          ),
          _InfoRow(
            label: 'Final agreed fee',
            value: '₹${student.finalFee.toStringAsFixed(0)}',
          ),
          if (student.discount != 0)
            _InfoRow(
              label: 'Discount / difference',
              value: '₹${student.discount.toStringAsFixed(0)}',
            ),
          if (student.feeReason != null && student.feeReason!.isNotEmpty)
            _InfoRow(label: 'Remark', value: student.feeReason!),
          _InfoRow(label: 'Payment plan', value: student.paymentPlan.label),
          if (student.paymentPlan == PaymentPlan.installment &&
              currentAdmission != null &&
              currentAdmission.installments.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Installment schedule',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final item in currentAdmission.installments)
              _InfoRow(
                label: item.label,
                value:
                    '₹${item.amount.toStringAsFixed(0)} - '
                    'due ${'${item.dueDate.toLocal()}'.split(' ').first} '
                    '(${item.status.label})',
              ),
          ],
          const Divider(height: AppSpacing.lg),
          _InfoRow(label: 'Total paid', value: '₹${paid.toStringAsFixed(0)}'),
          _InfoRow(
            label: remaining < 0 ? 'Advance' : 'Due',
            value: '₹${remaining.abs().toStringAsFixed(0)}',
            valueColor: remaining > 0
                ? Theme.of(context).colorScheme.error
                : null,
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
        title: Text(
          '₹${payment.amount.toStringAsFixed(0)} - ${payment.mode.label}',
        ),
        subtitle: Text(
          '${payment.date.toLocal()}'.split(' ').first +
              (payment.remark != null ? ' - ${payment.remark}' : ''),
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
          SizedBox(
            width: 140,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}
