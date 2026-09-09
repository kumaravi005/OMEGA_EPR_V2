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
                  onTap: () => context.push(AppRoutes.adminMarkStudentAttendance),
                ),
                NavTile(
                  icon: Icons.badge_outlined,
                  label: 'Teacher attendance',
                  onTap: () => context.push(AppRoutes.adminMarkTeacherAttendance),
                ),
                NavTile(
                  icon: Icons.assignment_outlined,
                  label: 'Tests & results',
                  onTap: () => context.push(AppRoutes.adminTests),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
