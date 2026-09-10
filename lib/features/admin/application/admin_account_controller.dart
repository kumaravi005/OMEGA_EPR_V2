import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/account_provisioning_service.dart';
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

final adminAccountControllerProvider = Provider<AdminAccountController>(
  (ref) => AdminAccountController(ref),
);

/// All accounts, for the admin's account list. Requires the caller to be
/// an admin (enforced by firestore.rules `allow list`).
final allAccountsProvider = StreamProvider<List<UserAccount>>((ref) {
  return ref.watch(userAccountRepositoryProvider).watchAll();
});

class AdminAccountController {
  AdminAccountController(this._ref);

  final Ref _ref;

  /// Creates a new admin/teacher/student login account. Teacher and
  /// student *profiles* (the rich forms with photo/DOB/fees/etc.) build
  /// on top of this via [AccountProvisioningService] directly, so they
  /// can write their extra profile document in the same provisioning
  /// step - see TeacherFormController / StudentFormController.
  Future<void> createAccount({
    required String accountId,
    required String password,
    required String displayName,
    required UserRole role,
  }) async {
    final normalizedId = accountId.trim().toLowerCase();
    final email = '$normalizedId@${AppConstants.accountEmailDomain}';

    try {
      await _ref
          .read(accountProvisioningServiceProvider)
          .createAccount(
            email: email,
            password: password,
            writeProfile: (uid) async {
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
              await _ref.read(userAccountRepositoryProvider).set(uid, account);
            },
          );
    } catch (error) {
      throw AdminActionFailure(mapAccountCreationError(error));
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
      throw const AdminActionFailure(
        'Could not reset the session. Please try again.',
      );
    }
  }

  Future<void> setActive(String uid, bool active) async {
    try {
      await _ref.read(userAccountRepositoryProvider).updateFields(uid, {
        'active': active,
        'updatedAt': Timestamp.now(),
      });
    } catch (_) {
      throw const AdminActionFailure(
        'Could not update the account. Please try again.',
      );
    }
  }
}
