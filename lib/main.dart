import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/services/crashlytics_service.dart';
import 'core/utils/app_logger.dart';
import 'features/auth/application/device_id_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await CrashlyticsService.initialize();
  } catch (error, stackTrace) {
    // Expected until real Firebase project values are added — see
    // docs/firebase-setup.md. The app still runs so the architecture/theme
    // foundation can be reviewed without a live backend.
    AppLogger.error('Firebase initialization skipped', error, stackTrace);
  }

  // Resolved up front so deviceIdProvider (single-device session
  // enforcement) is never null by the time a login attempt can happen.
  // Timed out defensively so a plugin hiccup can never leave the app
  // stuck before runApp is even called.
  final container = ProviderContainer();
  try {
    await container
        .read(sharedPreferencesProvider.future)
        .timeout(const Duration(seconds: 5));
  } catch (error, stackTrace) {
    AppLogger.error('SharedPreferences preload failed', error, stackTrace);
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const OmegaApp()),
  );
}
