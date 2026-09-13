import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../academics/data/academics_repositories.dart';
import '../../auth/application/auth_providers.dart';
import '../../batches/data/batch_repository.dart';
import '../data/teacher_assignment_repository.dart';

/// A signed-in teacher's own read-only view of their current teaching
/// assignments (Set 22 section 10) - session/class/batch/subject/status,
/// nothing editable: "only Admin manages assignments." Uses
/// `ownTeacherAssignmentsProvider`, the same rule-constrained
/// `teacherId ==` query every other "my own records" screen in this
/// project uses (`teacherOwnAttendanceProvider`, `ownTeacherProfileProvider`).
class MyAssignmentsScreen extends ConsumerWidget {
  const MyAssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(currentUserAccountProvider).valueOrNull;
    final teacherId = account?.uid;

    if (teacherId == null) {
      return const Scaffold(
        body: Center(child: Text('Not signed in.')),
      );
    }

    final assignmentsAsync = ref.watch(ownTeacherAssignmentsProvider(teacherId));
    final sessionsAsync = ref.watch(allAcademicSessionsProvider);
    final classesAsync = ref.watch(allSchoolClassesProvider);
    final batchesAsync = ref.watch(allBatchesProvider);
    final subjectsAsync = ref.watch(allSubjectsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My assignments')),
      body: SafeArea(
        child: assignmentsAsync.when(
          loading: () => const LoadingView(message: 'Loading assignments...'),
          error: (error, stackTrace) =>
              ErrorView(message: 'Could not load your assignments.\n$error'),
          data: (assignments) {
            if (assignments.isEmpty) {
              return const EmptyView(
                message: 'No teaching assignments yet.',
              );
            }
            final sessions = sessionsAsync.valueOrNull ?? const [];
            final classes = classesAsync.valueOrNull ?? const [];
            final batches = batchesAsync.valueOrNull ?? const [];
            final subjects = subjectsAsync.valueOrNull ?? const [];

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: assignments.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final assignment = assignments[index];
                final sessionName = sessions
                    .where((s) => s.sessionId == assignment.academicSessionId)
                    .firstOrNull
                    ?.name;
                final className = classes
                    .where((c) => c.classId == assignment.classId)
                    .firstOrNull
                    ?.name;
                final batchName = batches
                    .where((b) => b.batchId == assignment.batchId)
                    .firstOrNull
                    ?.name;
                final subjectName = subjects
                    .where((s) => s.subjectId == assignment.subjectId)
                    .firstOrNull
                    ?.name;

                return Card(
                  child: ListTile(
                    title: Text(subjectName ?? 'Unknown subject'),
                    subtitle: Text(
                      '${className ?? 'Unknown class'} - ${batchName ?? 'Unknown batch'}\n'
                      '${sessionName ?? 'Unknown session'}',
                    ),
                    isThreeLine: true,
                    trailing: Chip(
                      label: Text(assignment.active ? 'Active' : 'Inactive'),
                      backgroundColor: assignment.active
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
