import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';

/// Public landing area - reachable without signing in. The full public
/// website/content system (gallery, announcements, enquiries, ...) is a
/// later phase; this only establishes that a public route exists and
/// doesn't require authentication.
class PublicHomeScreen extends StatelessWidget {
  const PublicHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          TextButton(
            onPressed: () => context.go(AppRoutes.login),
            child: const Text('Sign in', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppConstants.appName,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppCard(
                    child: Text(
                      'The public site (announcements, gallery, admissions enquiries) is coming in a later phase. '
                      'Admins, teachers and students can sign in with the Account ID and password given to them.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(label: 'Sign in', onPressed: () => context.go(AppRoutes.login)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
