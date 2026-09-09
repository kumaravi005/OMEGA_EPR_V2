import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../auth/application/auth_providers.dart';

/// Placeholder teacher area, proving role-based routing works. The real
/// teacher dashboard (batches, attendance, homework, ...) is a later
/// phase.
class TeacherHomeScreen extends ConsumerWidget {
  const TeacherHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(currentUserAccountProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authControllerProvider).logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: AppCard(
            child: Text(
              'Welcome, ${account?.displayName ?? 'Teacher'}.\n\n'
              'The teacher dashboard (batches, attendance, homework, results) will be built in a later phase. '
              'This screen only confirms that teacher sign-in and role-based routing work.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ),
    );
  }
}
