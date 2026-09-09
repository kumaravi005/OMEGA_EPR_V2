import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Wires uncaught Flutter/Dart errors into Firebase Crashlytics.
///
/// Call [initialize] once from `main()`, after `Firebase.initializeApp`.
/// Crashlytics has no web implementation, so this is a no-op on web.
abstract final class CrashlyticsService {
  static Future<void> initialize() async {
    if (kIsWeb) return;

    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: true);
      return true;
    };
  }
}
