import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/nav_tile.dart';
import '../../auth/application/auth_providers.dart';

/// Admin's landing screen: a simple list of the sections built so far.
/// Full dashboards/reports are a later phase.
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
                  icon: Icons.people_alt_outlined,
                  label: 'Students',
                  onTap: () => context.push(AppRoutes.adminStudents),
                ),
                NavTile(
                  icon: Icons.currency_rupee_outlined,
                  label: 'Fee dues',
                  onTap: () => context.push(AppRoutes.adminFeeDues),
                ),
                NavTile(
                  icon: Icons.event_available_outlined,
                  label: 'Student attendance',
                  onTap: () =>
                      context.push(AppRoutes.adminMarkStudentAttendance),
                ),
                NavTile(
                  icon: Icons.badge_outlined,
                  label: 'Teacher attendance',
                  onTap: () =>
                      context.push(AppRoutes.adminMarkTeacherAttendance),
                ),
                NavTile(
                  icon: Icons.assignment_outlined,
                  label: 'Tests & results',
                  onTap: () => context.push(AppRoutes.adminTests),
                ),
                NavTile(
                  icon: Icons.contact_phone_outlined,
                  label: 'Admission enquiries',
                  onTap: () => context.push(AppRoutes.adminEnquiries),
                ),
                NavTile(
                  icon: Icons.call_outlined,
                  label: 'Callback requests',
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
                  icon: Icons.info_outline,
                  label: 'Institute profile',
                  onTap: () => context.push(AppRoutes.adminInstituteProfile),
                ),
                NavTile(
                  icon: Icons.notifications_outlined,
                  label: 'Notifications',
                  onTap: () => context.push(AppRoutes.adminNotifications),
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
