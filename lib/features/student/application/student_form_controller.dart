import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/account_provisioning_service.dart';
import '../../../data/models/gender.dart';
import '../../auth/data/user_account.dart';
import '../../auth/data/user_account_repository.dart';
import '../data/student_profile.dart';
import '../data/student_repository.dart';

/// A clean, user-facing reason a student admission/update failed. Never
/// wraps a raw Firebase error message.
class StudentFormFailure implements Exception {
  const StudentFormFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

final studentFormControllerProvider = Provider<StudentFormController>(
  (ref) => StudentFormController(ref),
);

class StudentFormController {
  StudentFormController(this._ref);

  final Ref _ref;

  /// Admits a new student: creates their login account (`users/{uid}`,
  /// role: student) and their admission/fee record (`students/{uid}`)
  /// together.
  Future<void> admitStudent({
    required String accountId,
    required String password,
    required String name,
    required String fatherName,
    required DateTime dateOfBirth,
    required Gender gender,
    required String address,
    required String className,
    required String board,
    required String batchId,
    required String academicSession,
    required String primaryMobile,
    required String? secondaryMobile,
    required double standardFee,
    required double finalFee,
    required String? feeReason,
    required PaymentPlan paymentPlan,
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
              await _ref
                  .read(userAccountRepositoryProvider)
                  .set(
                    uid,
                    UserAccount(
                      uid: uid,
                      accountId: normalizedId,
                      role: UserRole.student,
                      displayName: name.trim(),
                      active: true,
                      createdAt: now,
                      updatedAt: now,
                      lastLoginAt: null,
                      session: null,
                    ),
                  );
              await _ref
                  .read(studentRepositoryProvider)
                  .set(
                    uid,
                    StudentProfile(
                      uid: uid,
                      accountId: normalizedId,
                      name: name.trim(),
                      fatherName: fatherName.trim(),
                      dateOfBirth: dateOfBirth,
                      gender: gender,
                      address: address.trim(),
                      className: className.trim(),
                      board: board.trim(),
                      batchId: batchId,
                      academicSession: academicSession.trim(),
                      primaryMobile: primaryMobile.trim(),
                      secondaryMobile: secondaryMobile?.trim(),
                      standardFee: standardFee,
                      finalFee: finalFee,
                      feeReason: feeReason?.trim(),
                      paymentPlan: paymentPlan,
                      active: true,
                      createdAt: now,
                      updatedAt: now,
                    ),
                  );
            },
          );
    } catch (error) {
      throw StudentFormFailure(mapAccountCreationError(error));
    }
  }

  /// Edits an existing student's admission/fee record. Does not touch
  /// their login account (Account ID/password/role are set once at
  /// admission and never change).
  Future<void> updateStudent({
    required StudentProfile existing,
    required String name,
    required String fatherName,
    required DateTime dateOfBirth,
    required Gender gender,
    required String address,
    required String className,
    required String board,
    required String batchId,
    required String academicSession,
    required String primaryMobile,
    required String? secondaryMobile,
    required double standardFee,
    required double finalFee,
    required String? feeReason,
    required PaymentPlan paymentPlan,
  }) async {
    try {
      await _ref
          .read(studentRepositoryProvider)
          .set(
            existing.uid,
            StudentProfile(
              uid: existing.uid,
              accountId: existing.accountId,
              name: name.trim(),
              fatherName: fatherName.trim(),
              dateOfBirth: dateOfBirth,
              gender: gender,
              address: address.trim(),
              className: className.trim(),
              board: board.trim(),
              batchId: batchId,
              academicSession: academicSession.trim(),
              primaryMobile: primaryMobile.trim(),
              secondaryMobile: secondaryMobile?.trim(),
              standardFee: standardFee,
              finalFee: finalFee,
              feeReason: feeReason?.trim(),
              paymentPlan: paymentPlan,
              active: existing.active,
              createdAt: existing.createdAt,
              updatedAt: DateTime.now(),
            ),
          );
      await _ref.read(userAccountRepositoryProvider).updateFields(
        existing.uid,
        {'displayName': name.trim(), 'updatedAt': DateTime.now()},
      );
    } catch (_) {
      throw const StudentFormFailure(
        'Could not save changes. Please try again.',
      );
    }
  }
}
