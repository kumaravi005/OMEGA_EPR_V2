import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/contact_actions.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../enquiries/presentation/request_callback_dialog.dart';
import '../../enquiries/presentation/submit_enquiry_dialog.dart';
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
    final instituteName = profileAsync.valueOrNull?.name ?? AppConstants.appName;

    return Scaffold(
      appBar: AppBar(
        title: Text(instituteName),
        actions: [
          TextButton(
            onPressed: () => context.go(AppRoutes.login),
            child: const Text('Sign in', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    _HeroSection(instituteName: instituteName, tagline: profileAsync.valueOrNull?.tagline),
                    const SizedBox(height: AppSpacing.lg),
                    const _BannersSection(),
                    const _UpcomingBatchesSection(),
                    const _GallerySection(),
                    const _AnnouncementsSection(),
                    _AboutSection(about: profileAsync.valueOrNull?.about),
                    _ContactSection(profile: profileAsync.valueOrNull),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'Admission enquiry',
                            onPressed: () => showSubmitEnquiryDialog(context),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: AppButton(
                            label: 'Request a callback',
                            variant: AppButtonVariant.secondary,
                            onPressed: () => showRequestCallbackDialog(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
            const AdPopupTrigger(),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm, top: AppSpacing.lg),
      child: Text(text, style: Theme.of(context).textTheme.headlineMedium),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.instituteName, required this.tagline});

  final String instituteName;
  final String? tagline;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(instituteName, style: Theme.of(context).textTheme.headlineLarge, textAlign: TextAlign.center),
        if (tagline != null && tagline!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(tagline!, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
        ],
      ],
    );
  }
}

class _BannersSection extends ConsumerWidget {
  const _BannersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannersAsync = ref.watch(allBannersProvider);
    final live = bannersAsync.valueOrNull?.where((b) => b.isLive(DateTime.now())).toList() ?? const [];
    if (live.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 220,
      child: PageView(
        children: [
          for (final banner in live)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      child: Image.network(
                        banner.imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image_outlined)),
                      ),
                    ),
                  ),
                  Text(banner.title, style: Theme.of(context).textTheme.titleLarge),
                  if (banner.description != null) Text(banner.description!, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _UpcomingBatchesSection extends ConsumerWidget {
  const _UpcomingBatchesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchesAsync = ref.watch(allUpcomingBatchesProvider);
    final active = batchesAsync.valueOrNull?.where((b) => b.active).toList() ?? const [];
    if (active.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Upcoming batches'),
        for (final batch in active)
          AppCard(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${batch.title} - ${batch.className} (${batch.board})', style: Theme.of(context).textTheme.titleLarge),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(allGalleryItemsProvider);
    final active = itemsAsync.valueOrNull?.where((i) => i.active).toList() ?? const [];
    if (active.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Gallery'),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: AppSpacing.xs,
            mainAxisSpacing: AppSpacing.xs,
          ),
          itemCount: active.length,
          itemBuilder: (context, index) {
            final item = active[index];
            return ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: Image.network(
                item.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black12, child: Icon(Icons.broken_image_outlined)),
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
    final itemsAsync = ref.watch(allAnnouncementsProvider);
    final active = itemsAsync.valueOrNull?.where((a) => a.active).toList() ?? const [];
    if (active.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Announcements'),
        for (final item in active)
          AppCard(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: Theme.of(context).textTheme.titleLarge),
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
      children: [const _SectionTitle('About us'), AppCard(child: Text(about!))],
    );
  }
}

class _ContactSection extends StatelessWidget {
  const _ContactSection({required this.profile});

  final InstituteProfile? profile;

  @override
  Widget build(BuildContext context) {
    final phone = profile?.contactPhone;
    final email = profile?.contactEmail;
    final address = profile?.address;
    if (phone == null && email == null && address == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Contact us'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (address != null) Text(address),
              if (email != null) Text(email),
              if (phone != null) ...[
                Text(phone),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(label: 'Call', icon: Icons.call_outlined, onPressed: () => callNumber(phone)),
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
            ],
          ),
        ),
      ],
    );
  }
}
