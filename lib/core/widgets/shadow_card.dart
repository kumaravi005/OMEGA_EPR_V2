import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';

/// A white, rounded, brand-shadowed card with an optional tap ripple - the
/// surface every tile on the redesigned role dashboards is built from.
class ShadowCard extends StatelessWidget {
  const ShadowCard({
    super.key,
    required this.child,
    this.onTap,
    this.radius = AppSpacing.radiusLg,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: borderRadius,
        boxShadow: AppShadows.card,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(borderRadius: borderRadius, onTap: onTap, child: child),
      ),
    );
  }
}
