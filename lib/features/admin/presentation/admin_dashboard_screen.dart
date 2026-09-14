import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/nav_tile.dart';
import '../../auth/application/auth_providers.dart';

/// Admin's landing screen: a single list of every admin section, ordered
/// by domain adjacency (accounts/teachers/batches/assignments/students/
/// fees/attendance/homework/tests/results, then enquiries, then public
/// content, then configuration/notices/reports) rather than grouped under
/// visual section headers - this project's established "one flat NavTile
/// list per role" pattern (see `TeacherHomeScreen`/`StudentHomeScreen`).
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
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
                  icon: Icons.manage_accounts_outlined,
                  label: 'Login accounts',
                  onTap: () => context.push(AppRoutes.adminAccounts),
                ),
                NavTile(
                  icon: Icons.school_outlined,
                  label: 'Teachers',
                  onTap: () => context.push(AppRoutes.adminTeachers),
                ),
                NavTile(
                  icon: Icons.groups_outlined,
                  label: 'Batches',
                  onTap: () => context.push(AppRoutes.adminBatches),
                ),
                NavTile(
                  icon: Icons.assignment_ind_outlined,
                  label: 'Teacher assignments',
                  onTap: () => context.push(AppRoutes.adminTeacherAssignments),
                ),
                NavTile(
                  icon: Icons.people_alt_outlined,
                  label: 'Students',
                  onTap: () => context.push(AppRoutes.adminStudents),
                ),
                NavTile(
                  icon: Icons.currency_rupee_outlined,
                  label: 'Fees',
                  onTap: () => context.push(AppRoutes.adminFeeDues),
                ),
                NavTile(
                  icon: Icons.event_available_outlined,
                  label: 'Attendance',
                  onTap: () => context.push(AppRoutes.adminAttendance),
                ),
                NavTile(
                  icon: Icons.menu_book_outlined,
                  label: 'Homework & Assignments',
                  onTap: () => context.push(AppRoutes.adminAcademicWork),
                ),
                NavTile(
                  icon: Icons.assignment_outlined,
                  label: 'Tests',
                  onTap: () => context.push(AppRoutes.adminTests),
                ),
                NavTile(
                  icon: Icons.leaderboard_outlined,
                  label: 'Results',
                  onTap: () => context.push(AppRoutes.adminResults),
                ),
                NavTile(
                  icon: Icons.contact_phone_outlined,
                  label: 'Visitor enquiries',
                  onTap: () => context.push(AppRoutes.adminEnquiries),
                ),
                NavTile(
                  icon: Icons.call_outlined,
                  label: 'Callback requests (history)',
                  onTap: () => context.push(AppRoutes.adminCallbackRequests),
                ),
                NavTile(
                  icon: Icons.photo_library_outlined,
                  label: 'Gallery',
                  onTap: () => context.push(AppRoutes.adminGallery),
                ),
                NavTile(
                  icon: Icons.view_carousel_outlined,
                  label: 'Banners',
                  onTap: () => context.push(AppRoutes.adminBanners),
                ),
                NavTile(
                  icon: Icons.calendar_month_outlined,
                  label: 'Upcoming batches',
                  onTap: () => context.push(AppRoutes.adminUpcomingBatches),
                ),
                NavTile(
                  icon: Icons.campaign_outlined,
                  label: 'Advertisements',
                  onTap: () => context.push(AppRoutes.adminAdvertisements),
                ),
                NavTile(
                  icon: Icons.announcement_outlined,
                  label: 'Announcements',
                  onTap: () => context.push(AppRoutes.adminAnnouncements),
                ),
                NavTile(
                  icon: Icons.settings_outlined,
                  label: 'Configuration',
                  onTap: () => context.push(AppRoutes.adminConfiguration),
                ),
                NavTile(
                  icon: Icons.notifications_outlined,
                  label: 'Notifications',
                  onTap: () => context.push(AppRoutes.adminNotifications),
                ),
                NavTile(
                  icon: Icons.notification_important_outlined,
                  label: 'Notices',
                  onTap: () => context.push(AppRoutes.adminNotices),
                ),
                NavTile(
                  icon: Icons.summarize_outlined,
                  label: 'Reports & exports',
                  onTap: () => context.push(AppRoutes.adminReports),
                ),
                NavTile(
                  icon: Icons.badge_outlined,
                  label: 'Report templates',
                  onTap: () => context.push(AppRoutes.adminReportTemplates),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
