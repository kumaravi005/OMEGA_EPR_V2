import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/nav_tile.dart';

/// Admin's landing screen for the export/report engine - one nav hub to
/// the three export screens, each of which builds on the same shared
/// engine (`core/export/`).
class ReportsHubScreen extends StatelessWidget {
  const ReportsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports & exports')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                NavTile(
                  icon: Icons.people_alt_outlined,
                  label: 'Student export',
                  onTap: () => context.push(AppRoutes.adminStudentExport),
                ),
                NavTile(
                  icon: Icons.currency_rupee_outlined,
                  label: 'Fee dues export',
                  onTap: () => context.push(AppRoutes.adminFeeDuesExport),
                ),
                NavTile(
                  icon: Icons.leaderboard_outlined,
                  label: 'Test result export',
                  onTap: () => context.push(AppRoutes.adminTestResultExport),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
