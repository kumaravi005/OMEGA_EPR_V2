import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/contact_actions.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/section_header.dart';
import '../../enquiries/presentation/request_callback_dialog.dart';
import '../../enquiries/presentation/submit_enquiry_dialog.dart';
import '../../notices/data/notice.dart';
import '../../notices/data/notice_repository.dart';
import '../../notices/presentation/public_notice_dialog.dart';
import '../data/banner_item.dart';
import '../data/institute_profile.dart';
import '../data/public_content_repositories.dart';
import 'ad_popup.dart';

/// Public landing area - reachable without signing in. Every section
/// hides itself when there's no active content, rather than showing an
/// empty placeholder - a professional public site shouldn't advertise
/// its own emptiness.
class PublicHomeScreen extends ConsumerWidget {
  const PublicHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(instituteProfileProvider);
    final instituteName =
        profileAsync.valueOrNull?.name ?? AppConstants.appName;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: EdgeInsets.zero,
              children: [
                _TopHeader(
                  instituteName: instituteName,
                  tagline: profileAsync.valueOrNull?.tagline,
                  logoUrl: profileAsync.valueOrNull?.logoUrl,
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: AppButton(
                                  label: 'Admission enquiry',
                                  onPressed: () =>
                                      showSubmitEnquiryDialog(context),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: AppButton(
                                  label: 'Request a callback',
                                  variant: AppButtonVariant.secondary,
                                  onPressed: () =>
                                      showRequestCallbackDialog(context),
                                ),
                              ),
                            ],
                          ),
                          const _BannersSection(),
                          const _UpcomingBatchesSection(),
                          const _GallerySection(),
                          const _PublicNoticesSection(),
                          // Contact is placed right after Notices/Gallery
                          // (Set 31) - prominent, not buried at the very
                          // bottom - while Announcements/About still keep
                          // their own section below it.
                          _ContactSection(profile: profileAsync.valueOrNull),
                          const _AnnouncementsSection(),
                          _AboutSection(about: profileAsync.valueOrNull?.about),
                          const SizedBox(height: AppSpacing.xl),
                          _Footer(instituteName: instituteName),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const AdPopupTrigger(),
          ],
        ),
      ),
    );
  }
}

/// Compact top header (Set 31): a slim branded bar - small logo, institute
/// name + tagline, and the sign-in action - instead of the old full-height
/// blue hero band that duplicated the institute name already shown a
/// second time inside the hero carousel below it.
class _TopHeader extends StatelessWidget {
  const _TopHeader({
    required this.instituteName,
    required this.tagline,
    required this.logoUrl,
  });

  final String instituteName;
  final String? tagline;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final hasNetworkLogo = logoUrl != null && logoUrl!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            Color.alphaBlend(
              AppColors.accent.withValues(alpha: 0.14),
              Color.lerp(AppColors.primary, Colors.white, 0.35)!,
            ),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: hasNetworkLogo
                  ? Image.network(
                      logoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Image.asset(
                        'assets/branding/logo.png',
                        fit: BoxFit.cover,
                      ),
                    )
                  : Image.asset('assets/branding/logo.png', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  instituteName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
                if (tagline != null && tagline!.isNotEmpty)
                  Text(
                    tagline!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => context.go(AppRoutes.login),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              elevation: 0,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            icon: const Icon(Icons.person_outline, size: 16),
            label: const Text('Sign in'),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.instituteName});

  final String instituteName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: AppSpacing.sm),
        Text(
          instituteName,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '© ${DateTime.now().year} $instituteName. All rights reserved.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

/// Hero carousel section (Set 30): resolves the live, admin-ordered
/// banner list and hands it to [_HeroCarousel], which owns the actual
/// auto-slide/swipe/dot-indicator behavior. Kept separate from
/// [_HeroCarousel] so the carousel's State isn't rebuilt from scratch on
/// every Firestore emission - only when the resolved banner list itself
/// changes (Flutter's normal widget-update diffing).
class _BannersSection extends ConsumerWidget {
  const _BannersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannersAsync = ref.watch(activeBannersProvider);
    if (bannersAsync.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: LoadingView(),
      );
    }
    final live =
        bannersAsync.valueOrNull
            ?.where((b) => b.isLive(DateTime.now()))
            .toList() ??
        const [];
    if (live.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: _HeroCarousel(banners: live),
    );
  }
}

class _HeroCarousel extends StatefulWidget {
  const _HeroCarousel({required this.banners});

  final List<BannerItem> banners;

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _restartAutoSlide();
  }

  @override
  void didUpdateWidget(_HeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIds = oldWidget.banners.map((b) => b.bannerId).join(',');
    final newIds = widget.banners.map((b) => b.bannerId).join(',');
    if (oldIds != newIds) {
      _currentPage = 0;
      if (_controller.hasClients) _controller.jumpToPage(0);
      _restartAutoSlide();
    }
  }

  void _restartAutoSlide() {
    _timer?.cancel();
    // Pause safely with 0 or 1 banner - nothing to slide to.
    if (widget.banners.length <= 1) {
      _timer = null;
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      final next = (_currentPage + 1) % widget.banners.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 20 / 9,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.banners.length,
                onPageChanged: (index) =>
                    setState(() => _currentPage = index),
                itemBuilder: (context, index) =>
                    _HeroSlide(banner: widget.banners[index]),
              ),
            ),
          ),
          if (widget.banners.length > 1)
            Positioned(
              bottom: AppSpacing.sm,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.banners.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _currentPage ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _currentPage
                            ? AppColors.accent
                            : Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroSlide extends StatelessWidget {
  const _HeroSlide({required this.banner});

  final BannerItem banner;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          banner.imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const ColoredBox(
              color: AppColors.background,
              child: Center(child: CircularProgressIndicator()),
            );
          },
          errorBuilder: (_, _, _) => const ColoredBox(
            color: AppColors.background,
            child: Center(
              child: Icon(Icons.broken_image_outlined, size: 40),
            ),
          ),
        ),
        // Scrim so white title/description text stays readable over any
        // uploaded poster image.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
              colors: [
                Colors.black.withValues(alpha: 0.55),
                Colors.transparent,
              ],
              stops: const [0.0, 0.75],
            ),
          ),
        ),
        Positioned(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: AppSpacing.lg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                banner.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (banner.description != null) ...[
                const SizedBox(height: 2),
                Text(
                  banner.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
              if (banner.ctaText != null && banner.ctaUrl != null) ...[
                const SizedBox(height: AppSpacing.sm),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                    minimumSize: const Size(64, 36),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                  ),
                  onPressed: () => openExternalLink(banner.ctaUrl!),
                  child: Text(banner.ctaText!),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _UpcomingBatchesSection extends ConsumerWidget {
  const _UpcomingBatchesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchesAsync = ref.watch(activeUpcomingBatchesProvider);
    final active =
        batchesAsync.valueOrNull?.where((b) => b.active).toList() ?? const [];
    if (active.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Upcoming batches'),
        for (final batch in active)
          AppCard(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${batch.title} - ${batch.className} (${batch.board})',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text('Starts ${dateKey(batch.startDate)} - ${batch.timing}'),
                  if (batch.description != null) Text(batch.description!),
                  const SizedBox(height: AppSpacing.xs),
                  Chip(label: Text(batch.admissionStatus)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _GallerySection extends ConsumerWidget {
  const _GallerySection();

  /// Shown thumbnails before folding the rest behind a "+N More" tile
  /// (Set 31) - keeps the grid a clean, uniform 2 rows of 3 regardless of
  /// how many photos the admin has uploaded.
  static const _previewCount = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(activeGalleryItemsProvider);
    final active =
        itemsAsync.valueOrNull?.where((i) => i.active).toList() ?? const [];
    if (active.isEmpty) return const SizedBox.shrink();

    final overflow = active.length - _previewCount;
    final shown = overflow > 0
        ? active.take(_previewCount).toList()
        : active;
    final cellCount = shown.length + (overflow > 0 ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Gallery'),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: AppSpacing.xs,
            mainAxisSpacing: AppSpacing.xs,
            childAspectRatio: 1,
          ),
          itemCount: cellCount,
          itemBuilder: (context, index) {
            if (overflow > 0 && index == shown.length) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      active[_previewCount].imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: Colors.black12),
                    ),
                    ColoredBox(
                      color: Colors.black.withValues(alpha: 0.55),
                      child: Center(
                        child: Text(
                          '+$overflow More',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            final item = shown[index];
            return ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: Image.network(
                item.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Colors.black12,
                  child: Icon(Icons.broken_image_outlined),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AnnouncementsSection extends ConsumerWidget {
  const _AnnouncementsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(activeAnnouncementsProvider);
    final active =
        itemsAsync.valueOrNull?.where((a) => a.active).toList() ?? const [];
    if (active.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Announcements'),
        for (final item in active)
          AppCard(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(item.body),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.about});

  final String? about;

  @override
  Widget build(BuildContext context) {
    if (about == null || about!.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('About us'),
        AppCard(child: Text(about!)),
      ],
    );
  }
}

class _ContactSection extends StatelessWidget {
  const _ContactSection({required this.profile});

  final InstituteProfile? profile;

  @override
  Widget build(BuildContext context) {
    final phone = profile?.contactPhone;
    final secondaryPhone = profile?.secondaryPhone;
    final email = profile?.contactEmail;
    final address = profile?.address;
    final website = profile?.website;
    if (phone == null &&
        secondaryPhone == null &&
        email == null &&
        address == null &&
        website == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Contact us'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (address != null) _ContactRow(Icons.location_on_outlined, address),
              if (email != null) _ContactRow(Icons.email_outlined, email),
              if (website != null) _ContactRow(Icons.language_outlined, website),
              if (phone != null) ...[
                _ContactRow(Icons.phone_outlined, phone),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Call',
                        icon: Icons.call_outlined,
                        onPressed: () => callNumber(phone),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppButton(
                        label: 'WhatsApp',
                        icon: Icons.chat_outlined,
                        variant: AppButtonVariant.secondary,
                        onPressed: () => openWhatsApp(phone),
                      ),
                    ),
                  ],
                ),
              ],
              if (secondaryPhone != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _ContactRow(Icons.phone_outlined, secondaryPhone),
                    ),
                    AppButton(
                      label: 'Call',
                      icon: Icons.call_outlined,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => callNumber(secondaryPhone),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _PublicNoticesSection extends ConsumerWidget {
  const _PublicNoticesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noticesAsync = ref.watch(publicNoticesProvider);
    final notices = noticesAsync.valueOrNull ?? const <Notice>[];
    if (notices.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Notices'),
        for (final notice in notices)
          AppCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(notice.title),
              subtitle: Text(
                notice.type == NoticeType.other
                    ? (notice.otherTypeLabel ?? notice.type.label)
                    : notice.type.label,
              ),
              onTap: () => showPublicNoticeDialog(context, notice),
            ),
          ),
      ],
    );
  }
}
