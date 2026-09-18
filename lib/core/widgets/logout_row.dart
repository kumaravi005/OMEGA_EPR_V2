import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'shadow_card.dart';

/// The full-width Logout row that closes a role dashboard - its own
/// deliberate, danger-colored row rather than an icon beside the
/// notification buttons, so it's harder to mis-tap.
class LogoutRow extends StatelessWidget {
  const LogoutRow({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ShadowCard(
      radius: 14,
      onTap: onTap,
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, color: AppColors.danger, size: 22),
            SizedBox(width: AppSpacing.sm),
            Text(
              'Logout',
              style: TextStyle(
                color: AppColors.danger,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
