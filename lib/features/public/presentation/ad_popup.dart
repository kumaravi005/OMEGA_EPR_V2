import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/advertisement.dart';
import '../data/public_content_repositories.dart';

/// Whether the ad popup has already been shown this app session. A plain
/// in-memory provider is exactly "once per session" - it resets on a
/// fresh app start/reload, which *is* a new session, and never persists
/// across restarts (unlike SharedPreferences, which would make it "once
/// per install" instead).
final adPopupShownProvider = StateProvider<bool>((ref) => false);

/// Shows the first currently-live advertisement as a dismissible popup,
/// at most once per session. Call this once from the public home
/// screen's build method (it no-ops after the first successful show).
class AdPopupTrigger extends ConsumerWidget {
  const AdPopupTrigger({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alreadyShown = ref.watch(adPopupShownProvider);
    final adsAsync = ref.watch(allAdvertisementsProvider);

    if (!alreadyShown) {
      final ad = adsAsync.valueOrNull?.where((a) => a.isLive(DateTime.now())).firstOrNull;
      if (ad != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          if (ref.read(adPopupShownProvider)) return;
          ref.read(adPopupShownProvider.notifier).state = true;
          showDialog<void>(context: context, builder: (context) => _AdDialog(ad: ad));
        });
      }
    }

    return const SizedBox.shrink();
  }
}

class _AdDialog extends StatelessWidget {
  const _AdDialog({required this.ad});

  final Advertisement ad;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  child: Image.network(
                    ad.posterUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(
                      height: 160,
                      child: Center(child: Icon(Icons.broken_image_outlined, size: 48)),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(ad.title, style: Theme.of(context).textTheme.titleLarge),
                if (ad.description != null && ad.description!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(ad.description!),
                ],
                if (ad.buttonText != null && ad.buttonText!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  ElevatedButton(
                    onPressed: ad.buttonUrl == null
                        ? null
                        : () => launchUrl(Uri.parse(ad.buttonUrl!), mode: LaunchMode.externalApplication),
                    child: Text(ad.buttonText!),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
