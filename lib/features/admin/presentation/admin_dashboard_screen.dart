import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../auth/application/auth_providers.dart';

/// Admin's landing screen: a simple list of the sections Set 2/Set 3
/// have built so far. Full dashboards/reports are a later phase.
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
                _DashboardTile(
                  icon: Icons.manage_accounts_outlined,
                  label: 'Login accounts',
                  onTap: () => context.push(AppRoutes.adminAccounts),
                ),
                _DashboardTile(
                  icon: Icons.school_outlined,
                  label: 'Teachers',
                  onTap: () => context.push(AppRoutes.adminTeachers),
                ),
                _DashboardTile(
                  icon: Icons.groups_outlined,
                  label: 'Batches',
                  onTap: () => context.push(AppRoutes.adminBatches),
                ),
                _DashboardTile(
                  icon: Icons.people_alt_outlined,
                  label: 'Students',
                  onTap: () => context.push(AppRoutes.adminStudents),
                ),
                _DashboardTile(
                  icon: Icons.currency_rupee_outlined,
                  label: 'Fee dues',
                  onTap: () => context.push(AppRoutes.adminFeeDues),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  const _DashboardTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
