import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// The small rounded square that holds an icon on the redesigned tiles.
/// [isDanger] switches to the reserved danger palette (money owed).
class IconChip extends StatelessWidget {
  const IconChip({super.key, required this.icon, this.isDanger = false});

  final IconData icon;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: isDanger ? AppColors.dangerSoft : AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        size: 18,
        color: isDanger ? AppColors.danger : AppColors.primary,
      ),
    );
  }
}
