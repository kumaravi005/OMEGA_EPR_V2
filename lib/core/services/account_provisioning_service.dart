import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Creates a new Firebase Auth user without disturbing the caller's own
/// signed-in session, via a throwaway secondary [FirebaseApp] instance.
///
/// There are no Cloud Functions in this project (Spark plan). Calling
/// `createUserWithEmailAndPassword` on the *primary* Auth instance would
/// sign the app in as the newly-created user, hijacking the admin's own
/// session - this is what every account-creation flow (accounts,
/// teachers, students) uses instead, so that tricky bit only lives in
/// one place. See docs/architecture.md's "Why no Cloud Functions".
class AccountProvisioningService {
  /// Creates the Firebase Auth user for [email]/[password], then calls
  /// [writeProfile] with the new uid to persist whatever Firestore
  /// document(s) the account needs. If [writeProfile] throws, the
  /// just-created Auth user is deleted again so it isn't left orphaned.
  Future<T> createAccount<T>({
    required String email,
    required String password,
    required Future<T> Function(String uid) writeProfile,
  }) async {
    final secondaryApp = await Firebase.initializeApp(
      name: 'accountCreation-${DateTime.now().microsecondsSinceEpoch}',
      options: Firebase.app().options,
    );

    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user!.uid;

      try {
        return await writeProfile(uid);
      } catch (_) {
        await credential.user!.delete().catchError((_) {});
        rethrow;
      }
    } finally {
      await secondaryApp.delete();
    }
  }
}

final accountProvisioningServiceProvider = Provider<AccountProvisioningService>(
  (ref) => AccountProvisioningService(),
);

/// A clean, user-facing reason account creation failed. Shared by every
/// creation flow so the mapping only needs writing once.
String mapAccountCreationError(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'This Account ID is already in use.';
      case 'weak-password':
        return 'Password must be at least 8 characters.';
      case 'invalid-email':
        return 'Enter a valid Account ID.';
      case 'network-request-failed':
        return 'Could not reach the server. Check your connection.';
    }
  }
  return 'Could not create the account. Please try again.';
}
