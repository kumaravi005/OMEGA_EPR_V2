import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/contact_actions.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../application/student_form_controller.dart';
import '../data/student_profile.dart';
import '../data/student_repository.dart';
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
            AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Fees & payments',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  AppButton(
                    label: 'Open',
                    onPressed: () =>
                        context.push('${AppRoutes.adminFeeDues}/${student.uid}'),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

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
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
