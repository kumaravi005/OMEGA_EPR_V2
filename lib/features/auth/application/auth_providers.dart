import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../data/user_account.dart';
import '../data/user_account_repository.dart';
import 'device_id_service.dart';

/// A stale session (no heartbeat) this long is treated as abandoned and
/// may be reclaimed by a different device. Must match `firestore.rules`'
/// `selfSessionUpdateIsValid`.
const staleSessionAfter = Duration(minutes: 30);

/// How often the app refreshes its session's heartbeat while active.
const _heartbeatInterval = Duration(minutes: 5);

/// A clean, user-facing reason a login/session attempt failed. Never
/// wraps a raw Firebase error message.
enum AuthFailureReason {
  invalidCredentials,
  accountInactive,
  sessionActiveElsewhere,
  network,
  unknown,
}

class AuthFailure implements Exception {
  const AuthFailure(this.reason, this.message);

  final AuthFailureReason reason;
  final String message;

  @override
  String toString() => message;
}

/// The signed-in user's account document, live-updated. `null` means
/// signed out. This is what single-device enforcement and role-based
/// routing both watch.
final currentUserAccountProvider = StreamProvider<UserAccount?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final user = authState.valueOrNull;
  if (user == null) return Stream.value(null);

  return ref.watch(userAccountRepositoryProvider).watchById(user.uid);
});

/// One-shot message to show on the login screen after a forced sign-out
/// (session taken over, deactivated, etc). Cleared once displayed.
final sessionMessageProvider = StateProvider<String?>((ref) => null);

final authControllerProvider = Provider<AuthController>((ref) => AuthController(ref));

class AuthController {
  AuthController(this._ref);

  final Ref _ref;
  Timer? _heartbeatTimer;

  Future<void> login({required String accountId, required String password}) async {
    final normalizedId = accountId.trim().toLowerCase();
    final email = '$normalizedId@${AppConstants.accountEmailDomain}';
    final auth = _ref.read(authServiceProvider);
    final repository = _ref.read(userAccountRepositoryProvider);

    final User user;
    try {
      final credential = await auth.signInWithEmailAndPassword(email: email, password: password);
      user = credential.user!;
    } on FirebaseAuthException catch (error) {
      throw _mapSignInError(error);
    } catch (_) {
      throw const AuthFailure(AuthFailureReason.network, 'Could not reach the server. Check your connection.');
    }

    try {
      final account = await repository.getById(user.uid);
      if (account == null) {
        await auth.signOut();
        throw const AuthFailure(AuthFailureReason.invalidCredentials, 'Account ID or password is incorrect.');
      }
      if (!account.active) {
        await auth.signOut();
        throw const AuthFailure(
          AuthFailureReason.accountInactive,
          'This account is inactive. Contact your administrator.',
        );
      }

      final String deviceId;
      try {
        final prefs = await _ref.read(sharedPreferencesProvider.future);
        deviceId = DeviceIdService(prefs).getOrCreate();
      } catch (_) {
        await auth.signOut();
        throw const AuthFailure(AuthFailureReason.unknown, 'Could not start the app. Please try again.');
      }

      final existingSession = account.session;
      final sameDevice = existingSession?.deviceId == deviceId;
      final stale =
          existingSession != null && DateTime.now().difference(existingSession.lastSeenAt) > staleSessionAfter;
      if (existingSession != null && !sameDevice && !stale) {
        await auth.signOut();
        throw const AuthFailure(
          AuthFailureReason.sessionActiveElsewhere,
          'This account is already active on another device. Ask your administrator to reset it if this is a '
          'mistake.',
        );
      }

      final now = DateTime.now();
      await repository.updateFields(user.uid, {
        'session': DeviceSession(deviceId: deviceId, loginAt: now, lastSeenAt: now).toMap(),
        'lastLoginAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
    } on AuthFailure {
      rethrow;
    } on FirebaseException catch (error) {
      await auth.signOut();
      if (error.code == 'permission-denied') {
        throw const AuthFailure(
          AuthFailureReason.sessionActiveElsewhere,
          'This account is already active on another device. Ask your administrator to reset it if this is a '
          'mistake.',
        );
      }
      throw const AuthFailure(AuthFailureReason.network, 'Could not reach the server. Check your connection.');
    } catch (_) {
      await auth.signOut();
      throw const AuthFailure(AuthFailureReason.unknown, 'Something went wrong. Please try again.');
    }

    startHeartbeat();
  }

  Future<void> logout() async {
    stopHeartbeat();
    final auth = _ref.read(authServiceProvider);
    final uid = auth.currentUser?.uid;
    if (uid != null) {
      try {
        await _ref.read(userAccountRepositoryProvider).updateFields(uid, {'session': null});
      } catch (_) {
        // Best-effort: if this fails (e.g. offline), we still sign out
        // locally below. The session self-clears once it goes stale.
      }
    }
    await auth.signOut();
  }

  /// Called when [currentUserAccountProvider] shows the account is no
  /// longer validly signed in on this device (deactivated, session taken
  /// over/reset). Signs out locally and leaves a message for the login
  /// screen; does not attempt to clear the server session, since it's no
  /// longer this device's session to clear.
  Future<void> forceSignOutLocally(String message) async {
    stopHeartbeat();
    _ref.read(sessionMessageProvider.notifier).state = message;
    await _ref.read(authServiceProvider).signOut();
  }

  void startHeartbeat() {
    stopHeartbeat();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) => _sendHeartbeat());
  }

  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _sendHeartbeat() async {
    final auth = _ref.read(authServiceProvider);
    final uid = auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _ref.read(userAccountRepositoryProvider).updateFields(uid, {
        'session.lastSeenAt': Timestamp.now(),
      });
    } catch (_) {
      // Transient network issues shouldn't sign the user out; the next
      // heartbeat (or the next app open) will retry.
    }
  }

  AuthFailure _mapSignInError(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-email':
        return const AuthFailure(AuthFailureReason.invalidCredentials, 'Account ID or password is incorrect.');
      case 'user-disabled':
        return const AuthFailure(
          AuthFailureReason.accountInactive,
          'This account is inactive. Contact your administrator.',
        );
      case 'network-request-failed':
        return const AuthFailure(AuthFailureReason.network, 'Could not reach the server. Check your connection.');
      case 'too-many-requests':
        return const AuthFailure(
          AuthFailureReason.unknown,
          'Too many attempts. Please wait a moment and try again.',
        );
      default:
        return const AuthFailure(AuthFailureReason.unknown, 'Something went wrong. Please try again.');
    }
  }
}
