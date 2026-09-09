import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/data/user_account.dart';
import '../../auth/data/user_account_repository.dart';

/// A clean, user-facing reason an admin account-management action failed.
/// Never wraps a raw Firebase error message.
class AdminActionFailure implements Exception {
  const AdminActionFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

final adminAccountControllerProvider = Provider<AdminAccountController>((ref) => AdminAccountController(ref));

/// All accounts, for the admin's account list. Requires the caller to be
/// an admin (enforced by firestore.rules `allow list`).
final allAccountsProvider = StreamProvider<List<UserAccount>>((ref) {
  return ref.watch(userAccountRepositoryProvider).watchAll();
});

class AdminAccountController {
  AdminAccountController(this._ref);

  final Ref _ref;

  /// Creates a new account.
  ///
  /// There are no Cloud Functions in this project (Spark plan), so this
  /// runs entirely client-side. The one wrinkle: calling
  /// `createUserWithEmailAndPassword` on the *primary* Firebase Auth
  /// instance would sign the app in as the newly-created user, hijacking
  /// the admin's own session. A throwaway secondary [FirebaseApp]
  /// instance avoids that - it creates the Auth user in isolation, the
  /// admin's primary session is never touched, and the instance is torn
  /// down immediately after.
  Future<void> createAccount({
    required String accountId,
    required String password,
    required String displayName,
    required UserRole role,
  }) async {
    final normalizedId = accountId.trim().toLowerCase();
    final email = '$normalizedId@${AppConstants.accountEmailDomain}';

    final secondaryApp = await Firebase.initializeApp(
      name: 'accountCreation-${DateTime.now().microsecondsSinceEpoch}',
      options: Firebase.app().options,
    );

    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      final UserCredential credential;
      try {
        credential = await secondaryAuth.createUserWithEmailAndPassword(email: email, password: password);
      } on FirebaseAuthException catch (error) {
        throw AdminActionFailure(_mapCreateError(error));
      }

      final uid = credential.user!.uid;
      final now = DateTime.now();
      final account = UserAccount(
        uid: uid,
        accountId: normalizedId,
        role: role,
        displayName: displayName.trim(),
        active: true,
        createdAt: now,
        updatedAt: now,
        lastLoginAt: null,
        session: null,
      );

      try {
        await _ref.read(userAccountRepositoryProvider).set(uid, account);
      } catch (_) {
        await credential.user!.delete().catchError((_) {});
        throw const AdminActionFailure('Could not finish creating the account. Please try again.');
      }
    } finally {
      await secondaryApp.delete();
    }
  }

  /// Frees the account for login on a new device - for a legitimate
  /// device replacement, or to end an active session early.
  Future<void> resetSession(String uid) async {
    try {
      await _ref.read(userAccountRepositoryProvider).updateFields(uid, {
        'session': null,
        'updatedAt': Timestamp.now(),
      });
    } catch (_) {
      throw const AdminActionFailure('Could not reset the session. Please try again.');
    }
  }

  Future<void> setActive(String uid, bool active) async {
    try {
      await _ref.read(userAccountRepositoryProvider).updateFields(uid, {
        'active': active,
        'updatedAt': Timestamp.now(),
      });
    } catch (_) {
      throw const AdminActionFailure('Could not update the account. Please try again.');
    }
  }

  String _mapCreateError(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'This Account ID is already in use.';
      case 'weak-password':
        return 'Password must be at least 8 characters.';
      case 'invalid-email':
        return 'Enter a valid Account ID.';
      case 'network-request-failed':
        return 'Could not reach the server. Check your connection.';
      default:
        return 'Could not create the account. Please try again.';
    }
  }
}
