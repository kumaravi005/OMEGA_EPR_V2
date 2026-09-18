import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// The redesigned banner at the top of the student and teacher dashboards:
/// brand gradient, photo-ready avatar, greeting + name + role pill, and
/// notifications/notices icon buttons - shared by the admin, teacher and
/// student dashboards so the three roles read as one app.
class RoleDashboardHeader extends StatelessWidget {
  const RoleDashboardHeader({
    super.key,
    required this.greeting,
    required this.name,
    required this.roleLabel,
    required this.photoUrl,
    required this.onNotifications,
    required this.onNotices,
    this.notificationCount = 0,
    this.noticeCount = 0,
  });

  final String greeting;
  final String name;
  final String roleLabel;
  final String? photoUrl;
  final int notificationCount;
  final int noticeCount;
  final VoidCallback onNotifications;
  final VoidCallback onNotices;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        26,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      child: Row(
        children: [
          _Avatar(photoUrl: photoUrl),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  greeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 18 / 13,
                  ),
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 28 / 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        roleLabel.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.onAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          height: 14 / 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _HeaderIconButton(
            icon: Icons.notifications_outlined,
            tooltip: 'Notifications',
            badgeCount: notificationCount,
            onTap: onNotifications,
          ),
          const SizedBox(width: AppSpacing.sm),
          _HeaderIconButton(
            icon: Icons.campaign_outlined,
            tooltip: 'Notices',
            badgeCount: noticeCount,
            onTap: onNotices,
          ),
        ],
      ),
    );
  }
}

/// Circular photo frame (`cover`-fit) showing the person's real photo when
/// the admin has set one, otherwise a plain white silhouette.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.photoUrl});

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    const silhouette = Icon(Icons.person, color: Colors.white, size: 26);
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: ClipOval(
        child: hasPhoto
            ? Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => silhouette,
              )
            : silhouette,
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.badgeCount,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.16),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            if (badgeCount > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 16 / 11,
                    ),
                  ),
                ),
              ),
          ],
        ),
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
