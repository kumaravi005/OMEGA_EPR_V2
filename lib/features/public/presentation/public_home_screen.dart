import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
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
import '../data/course.dart';
import '../data/gallery_item.dart';
import '../data/institute_profile.dart';
import '../data/public_content_repositories.dart';
import '../data/upcoming_batch.dart';
import 'ad_popup.dart';

/// Landing-page-local design tokens (per the post-Set-33 redesign brief)
/// that are more precise than the app-wide [AppSpacing] scale calls for
/// elsewhere - kept local rather than widening the shared theme, since
/// admin/dashboard screens weren't part of this brief.
const _kButtonRadius = 14.0;
const _kChipRadius = 8.0;
const _kCardShadow = AppShadows.card;

/// Public landing area - reachable without signing in. Every section
/// hides itself when there's no active content, rather than showing an
/// empty placeholder - a professional public site shouldn't advertise
/// its own emptiness.
class PublicHomeScreen extends ConsumerStatefulWidget {
  const PublicHomeScreen({super.key});

  @override
  ConsumerState<PublicHomeScreen> createState() => _PublicHomeScreenState();
}

class _PublicHomeScreenState extends ConsumerState<PublicHomeScreen> {
  final _coursesKey = GlobalKey();
  final _batchesKey = GlobalKey();
  final _galleryKey = GlobalKey();
  final _contactKey = GlobalKey();

  void _scrollTo(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
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
                          const _BannersSection(),
                          const _StatStripSection(),
                          KeyedSubtree(
                            key: _coursesKey,
                            child: const _CoursesSection(),
                          ),
                          KeyedSubtree(
                            key: _batchesKey,
                            child: const _UpcomingBatchesSection(),
                          ),
                          KeyedSubtree(
                            key: _galleryKey,
                            child: const _GallerySection(),
                          ),
                          const _PublicNoticesSection(),
                          KeyedSubtree(
                            key: _contactKey,
                            child: _ContactSection(
                              profile: profileAsync.valueOrNull,
                            ),
                          ),
                          const _AnnouncementsSection(),
                          _AboutSection(about: profileAsync.valueOrNull?.about),
                          const SizedBox(height: AppSpacing.xl),
                          _Footer(
                            instituteName: instituteName,
                            onCourses: () => _scrollTo(_coursesKey),
                            onBatches: () => _scrollTo(_batchesKey),
                            onGallery: () => _scrollTo(_galleryKey),
                            onContact: () => _scrollTo(_contactKey),
                          ),
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

/// Header + primary CTAs (per the redesign brief): one contiguous
/// brand-primary gradient block - small rounded-square logo, institute
/// name/tagline, an outline "Sign in" action, then two full-width CTAs
/// (filled accent "Admission enquiry" + outline "Request a callback") -
/// with rounded bottom corners closing off the block before the page's
/// light background begins.
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(_kButtonRadius),
                child: SizedBox(
                  width: 58,
                  height: 58,
                  child: hasNetworkLogo
                      ? Image.network(
                          logoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Image.asset(
                            'assets/branding/logo.png',
                            fit: BoxFit.cover,
                          ),
                        )
                      : Image.asset(
                          'assets/branding/logo.png',
                          fit: BoxFit.cover,
                        ),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 28 / 22,
                      ),
                    ),
                    if (tagline != null && tagline!.isNotEmpty)
                      Text(
                        tagline!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 18 / 13,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () => context.go(AppRoutes.login),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                icon: const Icon(Icons.person_outline, size: 16),
                label: const Text('Sign in'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_kButtonRadius),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () => showSubmitEnquiryDialog(context),
                  child: const Text('Admission enquiry'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_kButtonRadius),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () => showRequestCallbackDialog(context),
                  child: const Text('Request a callback'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Stat strip (new, per the redesign brief): one white card, 3 columns
/// divided by hairlines. Figures are real (given directly by the admin)
/// rather than Firestore-backed - see the class doc comment on why they
/// aren't wired to an editable field yet.
class _StatStripSection extends StatelessWidget {
  const _StatStripSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: _kCardShadow,
      ),
      child: const Row(
        children: [
          Expanded(child: _StatItem(value: '6+', label: 'YEARS')),
          _StatDivider(),
          Expanded(child: _StatItem(value: '2,500+', label: 'STUDENTS')),
          _StatDivider(),
          Expanded(child: _StatItem(value: '92%', label: 'RESULT RATE')),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 36,
      child: VerticalDivider(width: 1, color: AppColors.border),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.instituteName,
    required this.onCourses,
    required this.onBatches,
    required this.onGallery,
    required this.onContact,
  });

  final String instituteName;
  final VoidCallback onCourses;
  final VoidCallback onBatches;
  final VoidCallback onGallery;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.md,
          children: [
            _FooterLink('Courses', onCourses),
            _FooterLink('Batches', onBatches),
            _FooterLink('Gallery', onGallery),
            _FooterLink('Contact', onContact),
          ],
        ),
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

class _FooterLink extends StatelessWidget {
  const _FooterLink(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      child: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Hero carousel section (Set 30): resolves the live, admin-ordered
/// banner list and hands it to [_HeroCarousel], which owns the actual
/// auto-slide/swipe/dot-indicator behavior. Kept separate from
/// [_HeroCarousel] so the carousel's State isn't rebuilt from scratch on
/// every Firestore emission - only when the resolved banner list itself
/// changes (Flutter's normal widget-update diffing).
///
/// The redesign brief describes a hero built from a flat gradient with
/// programmatic copy (no photo). This project's hero is instead real,
/// admin-uploaded poster images (Set 30's whole point) - replacing that
/// with static gradient text would delete working, real admin content,
/// which the brief itself says not to do ("not a rewrite of what the
/// school offers"). This keeps the real photo carousel and only applies
/// the brief's shadow/radius/scrim polish.
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
              boxShadow: _kCardShadow,
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
                  fontWeight: FontWeight.w800,
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
                    elevation: 0,
                    minimumSize: const Size(64, 36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_kButtonRadius),
                    ),
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

/// "Our courses": real, admin-managed course listings (see
/// `features/public/data/course.dart` and Admin -> Front office &
/// website -> Our courses).
class _CoursesSection extends ConsumerWidget {
  const _CoursesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(activeCoursesProvider);
    final courses =
        coursesAsync.valueOrNull?.where((c) => c.active).toList() ?? const [];
    if (courses.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Our courses'),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: courses.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) => _CourseCard(course: courses[index]),
          ),
        ),
      ],
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final hasImage = course.imageUrl != null && course.imageUrl!.isNotEmpty;
    final hasTag = course.trackTag != null && course.trackTag!.isNotEmpty;
    final hasChips = course.subjectChips.isNotEmpty;
    final hasSyllabus =
        course.syllabusUrl != null && course.syllabusUrl!.isNotEmpty;

    return Container(
      width: 172,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: _kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: hasImage
                    ? Image.network(
                        course.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _CourseCardFallbackIcon(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : _CourseCardFallbackIcon(
                        color: Theme.of(context).colorScheme.primary,
                      ),
              ),
              if (hasTag)
                Positioned(
                  left: AppSpacing.xs,
                  top: AppSpacing.xs,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(_kChipRadius),
                    ),
                    child: Text(
                      course.trackTag!.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.onAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  course.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 22 / 16,
                  ),
                ),
                if (hasChips) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final subject in course.subjectChips.take(3))
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSunken,
                            borderRadius: BorderRadius.circular(_kChipRadius),
                          ),
                          child: Text(
                            subject,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                ],
                if (hasSyllabus) ...[
                  const SizedBox(height: AppSpacing.xs),
                  InkWell(
                    onTap: () => openExternalLink(course.syllabusUrl!),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View syllabus',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(
                          Icons.arrow_forward,
                          size: 14,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseCardFallbackIcon extends StatelessWidget {
  const _CourseCardFallbackIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color.withValues(alpha: 0.08),
      child: Icon(Icons.school_outlined, color: color, size: 32),
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
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: active.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) =>
                _UpcomingBatchCard(batch: active[index]),
          ),
        ),
      ],
    );
  }
}

class _UpcomingBatchCard extends StatelessWidget {
  const _UpcomingBatchCard({required this.batch});

  final UpcomingBatch batch;

  @override
  Widget build(BuildContext context) {
    final isOpen = batch.admissionStatus.toLowerCase().contains('open');

    return Container(
      width: 240,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: _kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${batch.className} (${batch.board})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isOpen)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 12,
                        color: AppColors.success,
                      ),
                      SizedBox(width: 3),
                      Text(
                        'OPEN',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Chip(
                  label: Text(batch.admissionStatus),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                'Starts ${dateKey(batch.startDate)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _showUpcomingBatchDetail(context, batch),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Explore now'),
            ),
          ),
        ],
      ),
    );
  }
}

void _showUpcomingBatchDetail(BuildContext context, UpcomingBatch batch) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('${batch.title} - ${batch.className} (${batch.board})'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (batch.posterUrl != null && batch.posterUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                child: AspectRatio(
                  aspectRatio: 20 / 9,
                  child: Image.network(
                    batch.posterUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: Colors.black12),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            _DetailRow('Academic session', batch.academicSession),
            _DetailRow('Starts', dateKey(batch.startDate)),
            _DetailRow('Timing', batch.timing),
            _DetailRow('Status', batch.admissionStatus),
            if (batch.description != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(batch.description!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        AppButton(
          label: 'Admission enquiry',
          onPressed: () {
            Navigator.of(context).pop();
            showSubmitEnquiryDialog(context);
          },
        ),
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

/// Gallery: 2-column grid, fixed 4:3 tiles, caption overlay (the item's
/// own [GalleryItem.title], which the previous 3-column layout never
/// actually surfaced).
class _GallerySection extends ConsumerWidget {
  const _GallerySection();

  /// Shown thumbnails before folding the rest behind a "+N More" tile -
  /// keeps the grid a clean, uniform 3 rows of 2 regardless of how many
  /// photos the admin has uploaded.
  static const _previewCount = 6;

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
        SectionHeader(
          'Gallery',
          trailing: overflow > 0
              ? TextButton(
                  onPressed: () => _showGalleryAll(context, active),
                  child: const Text('View All'),
                )
              : null,
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            childAspectRatio: 4 / 3,
          ),
          itemCount: cellCount,
          itemBuilder: (context, index) {
            if (overflow > 0 && index == shown.length) {
              return InkWell(
                onTap: () => _showGalleryAll(context, active),
                child: _GalleryTile(
                  item: active[_previewCount],
                  overlayLabel: '+$overflow More',
                ),
              );
            }
            return _GalleryTile(item: shown[index]);
          },
        ),
      ],
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({required this.item, this.overlayLabel});

  final GalleryItem item;

  /// When set, replaces the caption with this (the "+N More" tile).
  final String? overlayLabel;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_kButtonRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            item.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: Colors.black12,
              child: Icon(Icons.broken_image_outlined),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: overlayLabel != null ? 0.55 : 0.5),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.6],
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.xs,
            right: AppSpacing.xs,
            bottom: AppSpacing.xs,
            child: overlayLabel != null
                ? Center(
                    child: Text(
                      overlayLabel!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

void _showGalleryAll(BuildContext context, List<GalleryItem> items) {
  showDialog<void>(
    context: context,
    builder: (context) => Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(title: const Text('Gallery')),
        body: GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            childAspectRatio: 4 / 3,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => _GalleryTile(item: items[index]),
        ),
      ),
    ),
  );
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
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              onTap: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(item.title),
                  content: SingleChildScrollView(child: Text(item.body)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  boxShadow: _kCardShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(_kChipRadius),
                      ),
                      child: const Icon(
                        Icons.campaign_outlined,
                        color: AppColors.onAccent,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            item.body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
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
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            boxShadow: _kCardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (address != null) _ContactRow(Icons.location_on_outlined, address),
              if (address != null && (email != null || website != null))
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Divider(height: 1),
                ),
              if (email != null) _ContactRow(Icons.email_outlined, email),
              if (website != null) ...[
                if (email != null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Divider(height: 1),
                  ),
                _ContactRow(Icons.language_outlined, website),
              ],
              if (phone != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(child: _ContactRow(Icons.phone_outlined, phone)),
                    AppButton(
                      label: 'Call',
                      icon: Icons.call_outlined,
                      onPressed: () => callNumber(phone),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    AppButton(
                      label: 'WhatsApp',
                      icon: Icons.chat_outlined,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => openWhatsApp(phone),
                    ),
                  ],
                ),
              ],
              if (secondaryPhone != null) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Divider(height: 1),
                ),
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
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

  static const _previewCount = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noticesAsync = ref.watch(publicNoticesProvider);
    final notices = noticesAsync.valueOrNull ?? const <Notice>[];
    if (notices.isEmpty) return const SizedBox.shrink();

    final overflow = notices.length - _previewCount;
    final shown = overflow > 0
        ? notices.take(_previewCount).toList()
        : notices;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Notices',
          trailing: overflow > 0
              ? TextButton(
                  onPressed: () => _showNoticesAll(context, notices),
                  child: const Text('See all'),
                )
              : null,
        ),
        for (final notice in shown) _NoticeTile(notice: notice),
      ],
    );
  }
}

class _NoticeTile extends StatelessWidget {
  const _NoticeTile({required this.notice});

  final Notice notice;

  @override
  Widget build(BuildContext context) {
    final isImportant = notice.type == NoticeType.important;
    final typeLabel = notice.type == NoticeType.other
        ? (notice.otherTypeLabel ?? notice.type.label)
        : notice.type.label;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: () => showPublicNoticeDialog(context, notice),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            boxShadow: _kCardShadow,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSunken,
                  borderRadius: BorderRadius.circular(_kChipRadius),
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notice.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isImportant)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSunken,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'IMPORTANT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${dateKey(notice.publishedAt ?? notice.createdAt)} · $typeLabel',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showNoticesAll(BuildContext context, List<Notice> notices) {
  showDialog<void>(
    context: context,
    builder: (context) => Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(title: const Text('Notices')),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            for (final notice in notices) _NoticeTile(notice: notice),
          ],
        ),
      ),
    ),
  );
}
