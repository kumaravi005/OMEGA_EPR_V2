import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/logout_row.dart';
import '../../../core/widgets/quick_tile.dart';
import '../../../core/widgets/role_dashboard_header.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/application/auth_providers.dart';
import '../../notices/data/notice_read_state.dart';
import '../data/teacher_repository.dart';

/// Teacher's landing screen: My assignments (Set 22/23's actual
/// teaching-scope list), Mark attendance/My attendance, Homework &
/// Assignments, Tests & results - each screen restricts write actions to
/// whatever the teacher's own active `TeacherAssignment`s currently cover
/// (see docs/architecture.md's "Teacher-scoped academic operations (Set
/// 23)"). No admin-only functionality (fees, teacher/student
/// administration, teacher assignment management, configuration, report
/// templates) is ever reachable from here.
///
/// Notifications/notices live in the header as icon buttons and Logout is
/// its own row at the bottom (post-Set-33 redesign brief). There are
/// deliberately no stat numbers or notice preview here - the app doesn't
/// surface any teacher-facing figures to show.
class TeacherHomeScreen extends ConsumerWidget {
  const TeacherHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(currentUserAccountProvider).valueOrNull;
    final unreadNotices = ref.watch(unreadNoticeCountProvider);
    final photoUrl = account == null
        ? null
        : ref
              .watch(ownTeacherProfileProvider(account.uid))
              .valueOrNull
              ?.photoUrl;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            RoleDashboardHeader(
              greeting: greetingFor(DateTime.now()),
              name: account?.displayName ?? 'Teacher',
              roleLabel: 'Teacher',
              photoUrl: photoUrl,
              noticeCount: unreadNotices,
              onNotifications: () =>
                  context.push(AppRoutes.teacherNotifications),
              onNotices: () => context.push(AppRoutes.teacherNotices),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeader('Teaching'),
                  GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: AppSpacing.sm,
                          mainAxisSpacing: AppSpacing.sm,
                          mainAxisExtent: 92,
                        ),
                    children: [
                      QuickTile(
                        icon: Icons.assignment_ind_outlined,
                        label: 'My assignments',
                        onTap: () => context.push(AppRoutes.teacherAssignments),
                      ),
                      QuickTile(
                        icon: Icons.how_to_reg_outlined,
                        label: 'Mark attendance',
                        onTap: () =>
                            context.push(AppRoutes.teacherMarkAttendance),
                      ),
                      QuickTile(
                        icon: Icons.event_available_outlined,
                        label: 'My attendance',
                        onTap: () => context.push(AppRoutes.teacherAttendance),
                      ),
                      QuickTile(
                        icon: Icons.menu_book_outlined,
                        label: 'Homework',
                        onTap: () =>
                            context.push(AppRoutes.teacherAcademicWork),
                      ),
                      QuickTile(
                        icon: Icons.assignment_outlined,
                        label: 'Tests & results',
                        onTap: () => context.push(AppRoutes.teacherTests),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  LogoutRow(
                    onTap: () => ref.read(authControllerProvider).logout(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
