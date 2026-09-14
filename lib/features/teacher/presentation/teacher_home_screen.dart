import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/nav_tile.dart';
import '../../auth/application/auth_providers.dart';
import '../../notices/data/notice_read_state.dart';

/// Teacher's landing screen: My assignments (Set 22/23's actual
/// teaching-scope list), Mark attendance/My attendance, Homework &
/// Assignments, Tests & results - each screen restricts write actions to
/// whatever the teacher's own active `TeacherAssignment`s currently cover
/// (see docs/architecture.md's "Teacher-scoped academic operations (Set
/// 23)"). No admin-only functionality (fees, teacher/student
/// administration, teacher assignment management, configuration, report
/// templates) is ever reachable from here.
class TeacherHomeScreen extends ConsumerWidget {
  const TeacherHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(currentUserAccountProvider).valueOrNull;
    final unreadNotices = ref.watch(unreadNoticeCountProvider);

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
                  icon: Icons.assignment_ind_outlined,
                  label: 'My assignments',
                  onTap: () => context.push(AppRoutes.teacherAssignments),
                ),
                NavTile(
                  icon: Icons.how_to_reg_outlined,
                  label: 'Mark attendance',
                  onTap: () => context.push(AppRoutes.teacherMarkAttendance),
                ),
                NavTile(
                  icon: Icons.event_available_outlined,
                  label: 'My attendance',
                  onTap: () => context.push(AppRoutes.teacherAttendance),
                ),
                NavTile(
                  icon: Icons.menu_book_outlined,
                  label: 'Homework & Assignments',
                  onTap: () => context.push(AppRoutes.teacherAcademicWork),
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
                NavTile(
                  icon: Icons.notification_important_outlined,
                  label: 'Notices',
                  badgeCount: unreadNotices,
                  onTap: () => context.push(AppRoutes.teacherNotices),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
