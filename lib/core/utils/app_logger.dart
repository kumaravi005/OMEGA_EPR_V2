import 'dart:developer' as developer;

/// Minimal logging wrapper.
///
/// Centralising log output now means later phases (and Crashlytics
/// breadcrumbs) have a single place to route through, instead of scattered
/// `print`/`debugPrint` calls.
abstract final class AppLogger {
  static void info(String message) => developer.log(message, name: 'omega.info');

  static void warning(String message) => developer.log(message, name: 'omega.warning');

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(message, name: 'omega.error', error: error, stackTrace: stackTrace);
  }
}
