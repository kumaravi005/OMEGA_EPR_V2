import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/account_provisioning_service.dart';
import '../../../data/models/gender.dart';
import '../../auth/data/user_account.dart';
import '../../auth/data/user_account_repository.dart';
import '../data/teacher_profile.dart';
import '../data/teacher_repository.dart';

/// A clean, user-facing reason a teacher create/update failed. Never
/// wraps a raw Firebase error message.
class TeacherFormFailure implements Exception {
  const TeacherFormFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

final teacherFormControllerProvider = Provider<TeacherFormController>((ref) => TeacherFormController(ref));

class TeacherFormController {
  TeacherFormController(this._ref);

  final Ref _ref;

  /// Creates the teacher's login account (`users/{uid}`, role: teacher)
  /// and their profile (`teachers/{uid}`) together - see
  /// AccountProvisioningService for why this needs a secondary Firebase
  /// app instance instead of a Cloud Function.
  Future<void> createTeacher({
    required String accountId,
    required String password,
    required String name,
    required DateTime dateOfBirth,
    required Gender gender,
    required String qualification,
    required String address,
    required String primaryMobile,
    required String? secondaryMobile,
    required List<ClassSubjectAssignment> assignments,
  }) async {
    final normalizedId = accountId.trim().toLowerCase();
    final email = '$normalizedId@${AppConstants.accountEmailDomain}';

    try {
      await _ref.read(accountProvisioningServiceProvider).createAccount(
        email: email,
        password: password,
        writeProfile: (uid) async {
          final now = DateTime.now();
          await _ref
              .read(userAccountRepositoryProvider)
              .set(
                uid,
                UserAccount(
                  uid: uid,
                  accountId: normalizedId,
                  role: UserRole.teacher,
                  displayName: name.trim(),
                  active: true,
                  createdAt: now,
                  updatedAt: now,
                  lastLoginAt: null,
                  session: null,
                ),
              );
          await _ref
              .read(teacherRepositoryProvider)
              .set(
                uid,
                TeacherProfile(
                  uid: uid,
                  accountId: normalizedId,
                  name: name.trim(),
                  dateOfBirth: dateOfBirth,
                  gender: gender,
                  qualification: qualification.trim(),
                  address: address.trim(),
                  primaryMobile: primaryMobile.trim(),
                  secondaryMobile: secondaryMobile?.trim(),
                  assignments: assignments,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        },
      );
    } catch (error) {
      throw TeacherFormFailure(mapAccountCreationError(error));
    }
  }

  /// Edits an existing teacher's profile. Does not touch their login
  /// account (Account ID/password/role are set once at creation and
  /// never change - see docs/database-architecture.md).
  Future<void> updateTeacher({
    required TeacherProfile existing,
    required String name,
    required DateTime dateOfBirth,
    required Gender gender,
    required String qualification,
    required String address,
    required String primaryMobile,
    required String? secondaryMobile,
    required List<ClassSubjectAssignment> assignments,
  }) async {
    try {
      await _ref
          .read(teacherRepositoryProvider)
          .set(
            existing.uid,
            TeacherProfile(
              uid: existing.uid,
              accountId: existing.accountId,
              name: name.trim(),
              dateOfBirth: dateOfBirth,
              gender: gender,
              qualification: qualification.trim(),
              address: address.trim(),
              primaryMobile: primaryMobile.trim(),
              secondaryMobile: secondaryMobile?.trim(),
              assignments: assignments,
              createdAt: existing.createdAt,
              updatedAt: DateTime.now(),
            ),
          );
      // Keep the login account's display name in sync with the profile.
      await _ref.read(userAccountRepositoryProvider).updateFields(existing.uid, {
        'displayName': name.trim(),
        'updatedAt': DateTime.now(),
      });
    } catch (_) {
      throw const TeacherFormFailure('Could not save changes. Please try again.');
    }
  }
}
