import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/services/auth_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/offline_banner.dart';
import 'core/widgets/splash_view.dart';
import 'features/auth/application/auth_providers.dart';
import 'features/auth/application/device_id_service.dart';
import 'router.dart';

/// Root widget of the Omega Education Centre app.
class OmegaApp extends ConsumerStatefulWidget {
  const OmegaApp({super.key});

  @override
  ConsumerState<OmegaApp> createState() => _OmegaAppState();
}

class _OmegaAppState extends ConsumerState<OmegaApp> {
  /// Whether this device has previously held a valid, matching session.
  /// Guards against a false "session ended" message during the brief
  /// window right after login, before the session write has landed.
  bool _hadValidSession = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<Object?>>(
      currentUserAccountProvider,
      (previous, next) => _onAccountChanged(),
    );

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) {
        final isResolvingAuth = ref.watch(authStateChangesProvider).isLoading;
        if (isResolvingAuth) {
          return const SplashView(message: 'Connecting to Omega...');
        }
        return OfflineBanner(child: child ?? const SizedBox.shrink());
      },
    );
  }

  void _onAccountChanged() {
    final isSignedIn = ref.read(authStateChangesProvider).valueOrNull != null;
    final account = ref.read(currentUserAccountProvider).valueOrNull;
    final deviceId = ref.read(deviceIdProvider);

    final isValidNow =
        isSignedIn &&
        account != null &&
        account.active &&
        account.session?.deviceId == deviceId;

    if (isValidNow) {
      _hadValidSession = true;
      return;
    }

    if (!isSignedIn) {
      // A clean logout (or never having been signed in) - nothing to force.
      _hadValidSession = false;
      return;
    }

    if (!_hadValidSession) {
      // Still settling right after login (session write hasn't landed
      // yet) - wait for the next emission instead of treating this as an
      // invalidation.
      return;
    }

    _hadValidSession = false;
    final message = account == null
        ? 'Your account could not be found. Contact your administrator.'
        : !account.active
        ? 'This account has been deactivated. Contact your administrator.'
        : 'This account was signed in on another device.';
    ref.read(authControllerProvider).forceSignOutLocally(message);
  }
}
