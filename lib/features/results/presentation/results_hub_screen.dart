import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/nav_tile.dart';

/// Admin's entry point into Results & Ranking (Set 15) - "Subject-wise
/// Result" and "Test Result" both open the same underlying screen (a
/// Set 14 test always belongs to exactly one subject, so picking a
/// subject first vs. a test first are two doors into the same room -
/// see `TestResultScreen`'s doc comment), "Combined Result" opens the
/// distinct multi-subject view.
class ResultsHubScreen extends ConsumerWidget {
  const ResultsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                NavTile(
                  icon: Icons.menu_book_outlined,
                  label: 'Subject-wise result',
                  onTap: () => context.push(AppRoutes.adminTestResult),
                ),
                NavTile(
                  icon: Icons.fact_check_outlined,
                  label: 'Test result',
                  onTap: () => context.push(AppRoutes.adminTestResult),
                ),
                NavTile(
                  icon: Icons.stacked_bar_chart_outlined,
                  label: 'Combined result',
                  onTap: () => context.push(AppRoutes.adminCombinedResult),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
