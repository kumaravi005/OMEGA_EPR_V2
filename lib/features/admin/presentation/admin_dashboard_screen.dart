import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/logout_row.dart';
import '../../../core/widgets/nav_grid_tile.dart';
import '../../../core/widgets/role_dashboard_header.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/application/auth_providers.dart';

/// Admin's landing screen: every admin section, grouped under visual
/// headers by domain (people & academics, fees, communication, front
/// office/website, system) instead of one long flat list - the same 22
/// destinations as before, just organized so the screen reads as a
/// control center rather than a scroll-heavy menu.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(currentUserAccountProvider).valueOrNull;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            RoleDashboardHeader(
              greeting: greetingFor(DateTime.now()),
              name: account?.displayName ?? 'Admin',
              roleLabel: 'Admin',
              photoUrl: null,
              onNotifications: () => context.push(AppRoutes.adminNotifications),
              onNotices: () => context.push(AppRoutes.adminNotices),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeader('People & academics'),
                  _Grid([
                    _Dest(
                      Icons.manage_accounts_outlined,
                      'Login accounts',
                      AppRoutes.adminAccounts,
                    ),
                    _Dest(
                      Icons.school_outlined,
                      'Teachers',
                      AppRoutes.adminTeachers,
                    ),
                    _Dest(
                      Icons.groups_outlined,
                      'Batches',
                      AppRoutes.adminBatches,
                    ),
                    _Dest(
                      Icons.assignment_ind_outlined,
                      'Teacher assignments',
                      AppRoutes.adminTeacherAssignments,
                    ),
                    _Dest(
                      Icons.people_alt_outlined,
                      'Students',
                      AppRoutes.adminStudents,
                    ),
                    _Dest(
                      Icons.event_available_outlined,
                      'Attendance',
                      AppRoutes.adminAttendance,
                    ),
                    _Dest(
                      Icons.menu_book_outlined,
                      'Homework',
                      AppRoutes.adminAcademicWork,
                    ),
                    _Dest(
                      Icons.assignment_outlined,
                      'Tests',
                      AppRoutes.adminTests,
                    ),
                    _Dest(
                      Icons.leaderboard_outlined,
                      'Results',
                      AppRoutes.adminResults,
                    ),
                  ]),
                  const SectionHeader('Fees'),
                  _Grid([
                    _Dest(
                      Icons.currency_rupee_outlined,
                      'Fees',
                      AppRoutes.adminFeeDues,
                    ),
                  ]),
                  const SectionHeader('Communication'),
                  _Grid([
                    _Dest(
                      Icons.notifications_outlined,
                      'Notifications',
                      AppRoutes.adminNotifications,
                    ),
                    _Dest(
                      Icons.notification_important_outlined,
                      'Notices',
                      AppRoutes.adminNotices,
                    ),
                  ]),
                  const SectionHeader('Front office & website'),
                  _Grid([
                    _Dest(
                      Icons.contact_phone_outlined,
                      'Visitor enquiries',
                      AppRoutes.adminEnquiries,
                    ),
                    _Dest(
                      Icons.call_outlined,
                      'Callback requests',
                      AppRoutes.adminCallbackRequests,
                    ),
                    _Dest(
                      Icons.photo_library_outlined,
                      'Gallery',
                      AppRoutes.adminGallery,
                    ),
                    _Dest(
                      Icons.view_carousel_outlined,
                      'Banners',
                      AppRoutes.adminBanners,
                    ),
                    _Dest(
                      Icons.school_outlined,
                      'Our courses',
                      AppRoutes.adminCourses,
                    ),
                    _Dest(
                      Icons.calendar_month_outlined,
                      'Upcoming batches',
                      AppRoutes.adminUpcomingBatches,
                    ),
                    _Dest(
                      Icons.campaign_outlined,
                      'Advertisements',
                      AppRoutes.adminAdvertisements,
                    ),
                    _Dest(
                      Icons.announcement_outlined,
                      'Announcements',
                      AppRoutes.adminAnnouncements,
                    ),
                  ]),
                  const SectionHeader('System'),
                  _Grid([
                    _Dest(
                      Icons.settings_outlined,
                      'Configuration',
                      AppRoutes.adminConfiguration,
                    ),
                    _Dest(
                      Icons.summarize_outlined,
                      'Reports & exports',
                      AppRoutes.adminReports,
                    ),
                    _Dest(
                      Icons.badge_outlined,
                      'Report templates',
                      AppRoutes.adminReportTemplates,
                    ),
                  ]),
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

class _Dest {
  const _Dest(this.icon, this.label, this.route);

  final IconData icon;
  final String label;
  final String route;
}

class _Grid extends StatelessWidget {
  const _Grid(this.destinations);

  final List<_Dest> destinations;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      childAspectRatio: 0.95,
      children: [
        for (final dest in destinations)
          NavGridTile(
            icon: dest.icon,
            label: dest.label,
            onTap: () => context.push(dest.route),
          ),
      ],
    );
  }
}
