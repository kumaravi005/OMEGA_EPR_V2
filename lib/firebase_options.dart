import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Firebase configuration for this project.
///
/// This project has NOT been connected to a real Firebase project yet.
/// Follow the steps in docs/firebase-setup.md, then run:
///
///   flutterfire configure
///
/// from the project root. That command overwrites this file with the real
/// per-platform values from your Firebase project. Do not hand-edit the
/// values here — they are intentionally left unset so no invented/guessed
/// Firebase configuration is ever committed.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Firebase has not been configured for this project yet. '
      'Follow docs/firebase-setup.md, then run `flutterfire configure` '
      'from the project root — it will regenerate this file automatically.',
    );
  }
}
