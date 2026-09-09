/// App-wide, non-operational constants (branding/display only).
///
/// Institute-specific operational data (fees, batches, sessions, etc.)
/// must never live here — it belongs in Firestore, driven by
/// [FirestoreCollections].
abstract final class AppConstants {
  static const appName = 'Omega Education Centre';
}
