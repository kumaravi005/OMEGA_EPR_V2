import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/nav_tile.dart';

/// Admin's entry point into attendance marking and history (Set 13) -
/// organized the way the spec asks: Student Attendance, Teacher
/// Attendance, Attendance History (split into its student/teacher forms
/// here for clarity, same "one hub, one screen per concern" shape as
/// `AcademicConfigHubScreen`).
class AttendanceHubScreen extends ConsumerWidget {
  const AttendanceHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
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
                  icon: Icons.fact_check_outlined,
                  label: 'Student attendance history',
                  onTap: () =>
                      context.push(AppRoutes.adminStudentAttendanceHistory),
                ),
                NavTile(
                  icon: Icons.history_edu_outlined,
                  label: 'Teacher attendance history',
                  onTap: () =>
                      context.push(AppRoutes.adminTeacherAttendanceHistory),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
