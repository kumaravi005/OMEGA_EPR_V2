/// App-wide, non-operational constants (branding/display only).
///
/// Institute-specific operational data (fees, batches, sessions, etc.)
/// must never live here — it belongs in Firestore, driven by
/// [FirestoreCollections].
abstract final class AppConstants {
  static const appName = 'Omega Education Centre';

  /// Pseudo-domain used to turn a login Account ID into a Firebase Auth
  /// email identifier (e.g. "stu001" -> "stu001@omegaerp.local"). It never
  /// receives real mail - email/password auth just needs a syntactically
  /// valid, unique identifier per user. Must match
  /// `functions/src/index.ts`'s `ACCOUNT_EMAIL_DOMAIN` exactly.
  static const accountEmailDomain = 'omegaerp.local';

  /// Same pattern enforced server-side in `functions/src/index.ts`.
  static final accountIdPattern = RegExp(
    r'^[a-z0-9][a-z0-9._-]{1,22}[a-z0-9]$',
  );
}
