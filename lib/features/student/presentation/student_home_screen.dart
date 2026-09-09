import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/nav_tile.dart';
import '../../auth/application/auth_providers.dart';

/// Student/parent's landing screen: attendance, homework, assignments and
/// published test results for their own batch. A dedicated fee-summary
/// view for students (beyond what admin already sees in their profile -
/// see features/student/presentation/student_profile_screen.dart) is a
/// later phase.
class StudentHomeScreen extends ConsumerWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(currentUserAccountProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text('Student${account != null ? ' - ${account.displayName}' : ''}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authControllerProvider).logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                NavTile(
                  icon: Icons.event_available_outlined,
                  label: 'My attendance',
                  onTap: () => context.push(AppRoutes.studentAttendance),
                ),
                NavTile(
                  icon: Icons.menu_book_outlined,
                  label: 'Homework',
                  onTap: () => context.push(AppRoutes.studentHomework),
                ),
                NavTile(
                  icon: Icons.assignment_turned_in_outlined,
                  label: 'Assignments',
                  onTap: () => context.push(AppRoutes.studentAssignments),
                ),
                NavTile(
                  icon: Icons.grade_outlined,
                  label: 'My results',
                  onTap: () => context.push(AppRoutes.studentResults),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
