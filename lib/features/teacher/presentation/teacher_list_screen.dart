import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/teacher_profile.dart';
import '../data/teacher_repository.dart';

class TeacherListScreen extends ConsumerWidget {
  const TeacherListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teachersAsync = ref.watch(allTeachersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Teachers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.adminNewTeacher),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('New teacher'),
      ),
      body: SafeArea(
        child: teachersAsync.when(
          loading: () => const LoadingView(message: 'Loading teachers...'),
          error: (error, stackTrace) => ErrorView(message: 'Could not load teachers.\n$error'),
          data: (teachers) {
            if (teachers.isEmpty) {
              return const EmptyView(message: 'No teachers yet. Create one below.');
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: teachers.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) => _TeacherTile(teacher: teachers[index]),
            );
          },
        ),
      ),
    );
  }
}

class _TeacherTile extends StatelessWidget {
  const _TeacherTile({required this.teacher});

  final TeacherProfile teacher;

  @override
  Widget build(BuildContext context) {
    final assignmentSummary = teacher.assignments.isEmpty
        ? 'No class/subject assignments yet'
        : teacher.assignments.map((a) => '${a.className} - ${a.subject}').join(', ');

    return Card(
      child: ListTile(
        title: Text('${teacher.name} (${teacher.accountId})'),
        subtitle: Text('${teacher.qualification}\n$assignmentSummary', maxLines: 2, overflow: TextOverflow.ellipsis),
        isThreeLine: true,
        onTap: () => context.push('${AppRoutes.adminTeachers}/${teacher.uid}/edit'),
      ),
    );
  }
}
