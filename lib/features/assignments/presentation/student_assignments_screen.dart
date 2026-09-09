import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/application/auth_providers.dart';
import '../../student/data/student_repository.dart';
import 'assignment_list_screen.dart';

/// Resolves the signed-in student's own batch, then shows their (fixed,
/// read-only) assignment list.
class StudentAssignmentsScreen extends ConsumerWidget {
  const StudentAssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(currentUserAccountProvider).valueOrNull;
    if (account == null) return const Scaffold(body: LoadingView());

    final studentsAsync = ref.watch(allStudentsProvider);
    return studentsAsync.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (error, stackTrace) => Scaffold(body: ErrorView(message: 'Could not load your profile.\n$error')),
      data: (students) {
        final self = students.where((s) => s.uid == account.uid).firstOrNull;
        if (self == null) return const Scaffold(body: ErrorView(message: 'Student profile not found.'));
        return AssignmentListScreen(fixedBatchId: self.batchId);
      },
    );
  }
}
