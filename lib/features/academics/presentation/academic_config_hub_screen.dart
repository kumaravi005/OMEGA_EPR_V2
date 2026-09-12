import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/nav_tile.dart';
import '../application/academic_config_controller.dart';

/// Admin's entry point into every piece of centrally-configured
/// institute/academic master data (Set 9) - organized the way the spec
/// asks: Institute, Academic Session, Classes, Boards, Subjects.
class AcademicConfigHubScreen extends ConsumerWidget {
  const AcademicConfigHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuration')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                NavTile(
                  icon: Icons.info_outline,
                  label: 'Institute',
                  onTap: () => context.push(AppRoutes.adminInstituteProfile),
                ),
                NavTile(
                  icon: Icons.event_note_outlined,
                  label: 'Academic session',
                  onTap: () => context.push(AppRoutes.adminAcademicSessions),
                ),
                NavTile(
                  icon: Icons.class_outlined,
                  label: 'Classes',
                  onTap: () => context.push(AppRoutes.adminClasses),
                ),
                NavTile(
                  icon: Icons.account_balance_outlined,
                  label: 'Boards',
                  onTap: () => context.push(AppRoutes.adminBoards),
                ),
                NavTile(
                  icon: Icons.menu_book_outlined,
                  label: 'Subjects',
                  onTap: () => context.push(AppRoutes.adminSubjects),
                ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton.icon(
                  onPressed: () => _confirmSeed(context, ref),
                  icon: const Icon(Icons.playlist_add_check_outlined),
                  label: const Text('Load default classes, boards & subjects'),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    'Only adds entries that do not already exist - safe to run '
                    'more than once, and never overwrites anything you have '
                    'already edited.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSeed(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Load default master data?'),
        content: const Text(
          'This adds Class 5-12, CBSE/BSEB/Others, and the standard subject '
          'list (with the usual Class 5-8 / Class 9-12 subject split) - only '
          'for whatever does not already exist.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Load'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(academicConfigControllerProvider).seedDefaults();
      messenger.showSnackBar(
        const SnackBar(content: Text('Default master data loaded.')),
      );
    } on AcademicConfigFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}
