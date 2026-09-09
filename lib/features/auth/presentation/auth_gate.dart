import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import 'foundation_home_screen.dart';

/// Routes to the appropriate screen based on Firebase Authentication state.
///
/// Role-based destinations (admin/teacher/student dashboards, sign-in
/// forms) are built in the authentication/authorization phase. For now,
/// every state resolves to [FoundationHomeScreen], which proves the
/// Firebase + theme foundation is wired end-to-end.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (user) => FoundationHomeScreen(user: user),
      loading: () => const Scaffold(body: LoadingView(message: 'Connecting to Omega...')),
      error: (error, stackTrace) =>
          Scaffold(body: ErrorView(message: 'Unable to reach authentication service.\n$error')),
    );
  }
}
