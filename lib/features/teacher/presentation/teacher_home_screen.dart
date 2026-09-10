import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/nav_tile.dart';
import '../../auth/application/auth_providers.dart';

/// Teacher's landing screen: attendance (view own), homework, assignments
/// and tests/results for whichever batch they're working with. Full
/// batch/class-scoped dashboards (e.g. "only my assigned classes") are a
/// later phase - see docs/architecture.md.
class TeacherHomeScreen extends ConsumerWidget {
  const TeacherHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(currentUserAccountProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Teacher${account != null ? ' - ${account.displayName}' : ''}',
        ),
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
                  onTap: () => context.push(AppRoutes.teacherAttendance),
                ),
                NavTile(
                  icon: Icons.menu_book_outlined,
                  label: 'Homework',
                  onTap: () => context.push(AppRoutes.teacherHomework),
                ),
                NavTile(
                  icon: Icons.assignment_turned_in_outlined,
                  label: 'Assignments',
                  onTap: () => context.push(AppRoutes.teacherAssignments),
                ),
                NavTile(
                  icon: Icons.assignment_outlined,
                  label: 'Tests & results',
                  onTap: () => context.push(AppRoutes.teacherTests),
                ),
                NavTile(
                  icon: Icons.notifications_outlined,
                  label: 'Notifications',
                  onTap: () => context.push(AppRoutes.teacherNotifications),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
