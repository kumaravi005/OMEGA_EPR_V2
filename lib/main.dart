import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/services/crashlytics_service.dart';
import 'core/utils/app_logger.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await CrashlyticsService.initialize();
  } catch (error, stackTrace) {
    // Expected until real Firebase project values are added — see
    // docs/firebase-setup.md. The app still runs so the architecture/theme
    // foundation can be reviewed without a live backend.
    AppLogger.error('Firebase initialization skipped', error, stackTrace);
  }

  runApp(const ProviderScope(child: OmegaApp()));
}
