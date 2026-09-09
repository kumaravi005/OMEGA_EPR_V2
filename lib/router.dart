import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/routing/app_routes.dart';
import 'core/services/auth_service.dart';
import 'features/admin/presentation/admin_home_screen.dart';
import 'features/admin/presentation/create_account_screen.dart';
import 'features/auth/application/auth_providers.dart';
import 'features/auth/application/device_id_service.dart';
import 'features/auth/data/user_account.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/public/presentation/public_home_screen.dart';
import 'features/student/presentation/student_home_screen.dart';
import 'features/teacher/presentation/teacher_home_screen.dart';

/// The app's route table and role-based/session-based redirect logic.
///
/// This is the one place allowed to import across every feature - it's
/// the composition root, not `core/` (which stays feature-agnostic) and
/// not any single `features/*` module.
const _publicPaths = {AppRoutes.publicHome, AppRoutes.login};

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _GoRouterRefreshNotifier();
  ref.listen<AsyncValue<Object?>>(currentUserAccountProvider, (previous, next) => refresh.notify());
  // deviceIdProvider depends on SharedPreferences loading asynchronously;
  // re-run redirect once it resolves so a restored session isn't stuck on
  // the public page if this fires before that.
  ref.listen<AsyncValue<Object?>>(sharedPreferencesProvider, (previous, next) => refresh.notify());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.publicHome,
    refreshListenable: refresh,
    redirect: (context, state) => _redirect(ref, state),
    routes: [
      GoRoute(path: AppRoutes.publicHome, builder: (context, state) => const PublicHomeScreen()),
      GoRoute(path: AppRoutes.login, builder: (context, state) => const LoginScreen()),
      GoRoute(path: AppRoutes.admin, builder: (context, state) => const AdminHomeScreen()),
      GoRoute(
        path: AppRoutes.adminCreateAccount,
        builder: (context, state) => const CreateAccountScreen(),
      ),
      GoRoute(path: AppRoutes.teacher, builder: (context, state) => const TeacherHomeScreen()),
      GoRoute(path: AppRoutes.student, builder: (context, state) => const StudentHomeScreen()),
    ],
  );
});

String? _redirect(Ref ref, GoRouterState state) {
  final path = state.matchedLocation;
  final isPublicPath = _publicPaths.contains(path);

  final authAsync = ref.read(authStateChangesProvider);
  if (authAsync.isLoading) return null;

  final firebaseUser = authAsync.valueOrNull;
  if (firebaseUser == null) {
    return isPublicPath ? null : AppRoutes.login;
  }

  final accountAsync = ref.read(currentUserAccountProvider);
  if (accountAsync.isLoading) return null;

  final account = accountAsync.valueOrNull;
  // A missing/inactive account or a session claimed by another device is
  // handled by the app-level listener, which forces a sign-out with an
  // explanation - don't bounce the UI mid-way through that.
  if (account == null || !account.active) return null;

  final deviceId = ref.read(deviceIdProvider);
  if (deviceId == null || account.session?.deviceId != deviceId) return null;

  final home = _homeFor(account.role);
  if (isPublicPath) return home;
  if (!path.startsWith(home)) return home;
  return null;
}

String _homeFor(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return AppRoutes.admin;
    case UserRole.teacher:
      return AppRoutes.teacher;
    case UserRole.student:
      return AppRoutes.student;
  }
}

/// A [Listenable] go_router can watch, notified by [ref.listen] whenever
/// auth/session state changes, so it re-runs [redirect].
class _GoRouterRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
