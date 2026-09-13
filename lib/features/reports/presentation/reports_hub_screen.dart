import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/nav_tile.dart';

/// Admin's landing screen for the export/report engine (Set 6/7),
/// reorganized in Set 20 section 1 into categories rather than a flat
/// list of unrelated tiles - every report here builds on the same shared
/// engine (`core/export/`) and the same domain calculation helpers
/// (Set 15 results, Set 13 attendance, Set 19 fees), never a second copy
/// of any of them. Only reports that actually exist are listed.
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
                const _CategoryTitle('Students'),
                NavTile(
                  icon: Icons.people_alt_outlined,
                  label: 'Student data export',
                  onTap: () => context.push(AppRoutes.adminStudentExport),
                ),
                const _CategoryTitle('Attendance'),
                NavTile(
                  icon: Icons.event_available_outlined,
                  label: 'Student attendance report',
                  onTap: () => context.push(AppRoutes.adminStudentAttendanceHistory),
                ),
                NavTile(
                  icon: Icons.badge_outlined,
                  label: 'Teacher attendance report',
                  onTap: () => context.push(AppRoutes.adminTeacherAttendanceHistory),
                ),
                const _CategoryTitle('Tests & results'),
                NavTile(
                  icon: Icons.leaderboard_outlined,
                  label: 'Test result export',
                  onTap: () => context.push(AppRoutes.adminTestResultExport),
                ),
                const _CategoryTitle('Fees'),
                NavTile(
                  icon: Icons.currency_rupee_outlined,
                  label: 'Fee due report',
                  onTap: () => context.push(AppRoutes.adminFeeDuesExport),
                ),
                NavTile(
                  icon: Icons.receipt_long_outlined,
                  label: 'Payment report',
                  onTap: () => context.push(AppRoutes.adminPaymentReport),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryTitle extends StatelessWidget {
  const _CategoryTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
