import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// The branded banner at the top of each role's dashboard: a greeting,
/// the signed-in person's name, and their role - shared by the admin,
/// teacher and student home screens so the three dashboards read as one
/// family while still being visually distinct via [roleLabel]/[greeting].
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.greeting,
    required this.roleLabel,
    this.name,
    this.onSignOut,
  });

  final String greeting;
  final String roleLabel;
  final String? name;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  greeting,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
              if (onSignOut != null)
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  tooltip: 'Sign out',
                  onPressed: onSignOut,
                ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  name ?? roleLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                ),
                child: Text(
                  roleLabel,
                  style: const TextStyle(
                    color: AppColors.onAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Returns "Good morning"/"Good afternoon"/"Good evening" for [now].
String greetingFor(DateTime now) {
  if (now.hour < 12) return 'Good morning';
  if (now.hour < 17) return 'Good afternoon';
  return 'Good evening';
}
