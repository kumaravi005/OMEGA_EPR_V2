import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// A tappable row with an icon and a chevron - used by the admin/teacher/
/// student home screens to list the sections available to that role.
class NavTile extends StatelessWidget {
  const NavTile({super.key, required this.icon, required this.label, required this.onTap});

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
