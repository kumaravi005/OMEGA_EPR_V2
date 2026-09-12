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
import '../../academics/data/academics_repositories.dart';
import '../../academics/data/subject.dart';
import '../application/teacher_form_controller.dart';
import '../data/teacher_profile.dart';
import '../data/teacher_repository.dart';

class TeacherProfileScreen extends ConsumerWidget {
  const TeacherProfileScreen({super.key, required this.teacherUid});

  final String teacherUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teachersAsync = ref.watch(allTeachersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () =>
                context.push('${AppRoutes.adminTeachers}/$teacherUid/edit'),
          ),
        ],
      ),
      body: SafeArea(
        child: teachersAsync.when(
          loading: () => const LoadingView(),
          error: (error, stackTrace) =>
              ErrorView(message: 'Could not load teacher.\n$error'),
          data: (teachers) {
            final teacher = teachers
                .where((t) => t.uid == teacherUid)
                .firstOrNull;
            if (teacher == null) {
              return const ErrorView(message: 'Teacher not found.');
            }
            return _ProfileBody(teacher: teacher);
          },
        ),
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.teacher});

  final TeacherProfile teacher;

  Future<void> _toggleActive(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(teacherFormControllerProvider)
          .setActive(teacher, !teacher.active);
    } on TeacherFormFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(allSubjectsProvider);
    final subjects = subjectsAsync.valueOrNull ?? const <Subject>[];
    final subjectNames = subjects
        .where((s) => teacher.subjectIds.contains(s.subjectId))
        .map((s) => s.name)
        .toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PhotoAvatar(photoUrl: teacher.photoUrl),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacher.name,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      Text(
                        teacher.active ? 'Active' : 'Inactive',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(
                              color: teacher.active
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
                    onPressed: () => callNumber(teacher.primaryMobile),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: 'WhatsApp',
                    icon: Icons.chat_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => openWhatsApp(teacher.primaryMobile),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: teacher.active ? 'Deactivate teacher' : 'Activate teacher',
              variant: AppButtonVariant.secondary,
              onPressed: () => _toggleActive(context, ref),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Teacher information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(
                    label: 'Date of birth',
                    value: '${teacher.dateOfBirth.toLocal()}'.split(' ').first,
                  ),
                  _InfoRow(
                    label: 'Gender',
                    value: _genderLabel(teacher.gender.name),
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
                    'Professional information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(
                    label: 'Qualification',
                    value: teacher.qualification.isEmpty
                        ? 'Not specified'
                        : teacher.qualification,
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
                    'Contact information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(
                    label: 'Primary mobile',
                    value: teacher.primaryMobile,
                  ),
                  if (teacher.secondaryMobile != null &&
                      teacher.secondaryMobile!.isNotEmpty)
                    _InfoRow(
                      label: 'Secondary mobile',
                      value: teacher.secondaryMobile!,
                    ),
                  _InfoRow(label: 'Address', value: teacher.address),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Subjects taught',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (subjectNames.isEmpty)
                    const Text('No subjects assigned yet.')
                  else
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final name in subjectNames)
                          Chip(label: Text(name)),
                      ],
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
                  _InfoRow(label: 'Account ID', value: teacher.accountId),
                  _InfoRow(
                    label: 'Account status',
                    value: teacher.active ? 'Active' : 'Inactive',
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
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
