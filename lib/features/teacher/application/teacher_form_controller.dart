import 'package:cloud_firestore/cloud_firestore.dart';
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

/// What the admin sees after a successful teacher creation (Set 12
/// spec: "Teacher name, Teacher ID, Account ID") - never a password,
/// which is never stored in Firestore in the first place.
class TeacherCreationResult {
  const TeacherCreationResult({
    required this.teacherName,
    required this.teacherId,
    required this.accountId,
  });

  final String teacherName;
  final String teacherId;
  final String accountId;
}

final teacherFormControllerProvider = Provider<TeacherFormController>(
  (ref) => TeacherFormController(ref),
);

class TeacherFormController {
  TeacherFormController(this._ref);

  final Ref _ref;

  /// Creates the teacher's login account (`users/{uid}`, role: teacher)
  /// and their profile (`teachers/{uid}`) together - see
  /// AccountProvisioningService for why this needs a secondary Firebase
  /// app instance instead of a Cloud Function.
  Future<TeacherCreationResult> createTeacher({
    required String accountId,
    required String password,
    required String name,
    required DateTime dateOfBirth,
    required Gender gender,
    String? photoUrl,
    required String qualification,
    required String address,
    required String primaryMobile,
    required String? secondaryMobile,
    required List<String> subjectIds,
  }) async {
    final normalizedId = accountId.trim().toLowerCase();
    final email = '$normalizedId@${AppConstants.accountEmailDomain}';

    try {
      return await _ref
          .read(accountProvisioningServiceProvider)
          .createAccount(
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
                      photoUrl: _blankToNull(photoUrl),
                      qualification: qualification.trim(),
                      address: address.trim(),
                      primaryMobile: primaryMobile.trim(),
                      secondaryMobile: secondaryMobile?.trim(),
                      subjectIds: dedupeSubjectIds(subjectIds),
                      active: true,
                      createdAt: now,
                      updatedAt: now,
                    ),
                  );
              return TeacherCreationResult(
                teacherName: name.trim(),
                teacherId: uid,
                accountId: normalizedId,
              );
            },
          );
    } catch (error) {
      throw TeacherFormFailure(mapAccountCreationError(error));
    }
  }

  /// Edits an existing teacher's profile. Does not touch their login
  /// account beyond syncing `displayName` (Account ID/password/role are
  /// set once at creation and never change - see
  /// docs/database-architecture.md). Changing subjects here only ever
  /// changes teaching CAPABILITY going forward - there is no historical
  /// attendance/assignment data yet that this could disturb (Set 12
  /// spec: teacher-to-batch assignment isn't implemented yet).
  Future<void> updateTeacher({
    required TeacherProfile existing,
    required String name,
    required DateTime dateOfBirth,
    required Gender gender,
    String? photoUrl,
    required String qualification,
    required String address,
    required String primaryMobile,
    required String? secondaryMobile,
    required List<String> subjectIds,
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
              photoUrl: _blankToNull(photoUrl),
              qualification: qualification.trim(),
              address: address.trim(),
              primaryMobile: primaryMobile.trim(),
              secondaryMobile: secondaryMobile?.trim(),
              subjectIds: dedupeSubjectIds(subjectIds),
              active: existing.active,
              createdAt: existing.createdAt,
              updatedAt: DateTime.now(),
            ),
          );
      // Keep the login account's display name in sync with the profile.
      await _ref.read(userAccountRepositoryProvider).updateFields(
        existing.uid,
        {'displayName': name.trim(), 'updatedAt': DateTime.now()},
      );
    } catch (_) {
      throw const TeacherFormFailure(
        'Could not save changes. Please try again.',
      );
    }
  }

  /// Activates/deactivates both the teacher record and their login
  /// account together, so a deactivated teacher can no longer start a
  /// new login session (`selfSessionUpdateIsValid` already requires
  /// `resource.data.active == true` to claim one) - their historical
  /// records are never touched. Also clears the obsolete
  /// `assignments` field left over on any teacher created before Set 12
  /// (a pre-Set-12 document's `className`/`subject` free-text pairs
  /// have no replacement value - a full edit-form save already omits
  /// this field for any teacher touched that way, and this makes the
  /// same true for a teacher whose status is toggled without ever being
  /// otherwise edited).
  Future<void> setActive(TeacherProfile existing, bool active) async {
    try {
      final now = Timestamp.now();
      await _ref.read(teacherRepositoryProvider).updateFields(existing.uid, {
        'active': active,
        'updatedAt': now,
        'assignments': FieldValue.delete(),
      });
      await _ref.read(userAccountRepositoryProvider).updateFields(
        existing.uid,
        {'active': active, 'updatedAt': now},
      );
    } catch (_) {
      throw const TeacherFormFailure(
        'Could not update the teacher. Please try again.',
      );
    }
  }

  String? _blankToNull(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();
}
