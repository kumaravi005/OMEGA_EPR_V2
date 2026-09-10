import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/student_profile.dart';
import '../data/student_repository.dart';

class StudentListScreen extends ConsumerWidget {
  const StudentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(allStudentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Students')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.adminNewStudent),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Admit student'),
      ),
      body: SafeArea(
        child: studentsAsync.when(
          loading: () => const LoadingView(message: 'Loading students...'),
          error: (error, stackTrace) =>
              ErrorView(message: 'Could not load students.\n$error'),
          data: (students) {
            if (students.isEmpty) {
              return const EmptyView(message: 'No students admitted yet.');
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: students.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) =>
                  _StudentTile(student: students[index]),
            );
          },
        ),
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({required this.student});

  final StudentProfile student;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('${student.name} (${student.accountId})'),
        subtitle: Text(
          '${student.className} - ${student.board}   Final fee: ₹${student.finalFee.toStringAsFixed(0)}'
          '${student.active ? '' : '   (inactive)'}',
        ),
        onTap: () => context.push('${AppRoutes.adminStudents}/${student.uid}'),
      ),
    );
  }
}
