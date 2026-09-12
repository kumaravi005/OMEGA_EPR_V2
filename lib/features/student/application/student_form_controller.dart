import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/account_provisioning_service.dart';
import '../../../core/services/sequence_service.dart';
import '../../../data/models/gender.dart';
import '../../auth/data/user_account.dart';
import '../../auth/data/user_account_repository.dart';
import '../../batches/data/batch_repository.dart';
import '../../batches/data/installment_schedule_item.dart';
import '../data/student_admission.dart';
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

/// The account id + generated admission number handed back after a
/// successful admission, so the admin screen can show a clear
/// confirmation (Set 11 spec: "may show the generated Account ID" -
/// never a password, which is never stored in Firestore in the first
/// place).
class AdmissionResult {
  const AdmissionResult({
    required this.accountId,
    required this.admissionNumber,
  });

  final String accountId;
  final String admissionNumber;
}

final studentFormControllerProvider = Provider<StudentFormController>(
  (ref) => StudentFormController(ref),
);

class StudentFormController {
  StudentFormController(this._ref);

  final Ref _ref;

  /// Admits a new student: creates their login account (`users/{uid}`),
  /// their stable identity record (`students/{uid}`), and their first
  /// admission/fee record (`students/{uid}/admissions/{admissionId}`)
  /// together, then increments the chosen batch's `studentCount`.
  Future<AdmissionResult> admitStudent({
    required String accountId,
    required String password,
    required String name,
    required String fatherName,
    required DateTime dateOfBirth,
    required Gender gender,
    String? photoUrl,
    required String address,
    required String academicSessionId,
    required String academicSessionName,
    required String classId,
    required String className,
    required String batchId,
    String? boardId,
    String? boardCustomText,
    required String boardDisplayName,
    required String primaryMobile,
    required String? secondaryMobile,
    required double standardFee,
    required double finalFee,
    required String? feeReason,
    required PaymentPlan paymentPlan,
    required List<InstallmentScheduleItem> installments,
    required String configuredByUid,
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
              final sequenceNumber = await _ref
                  .read(sequenceServiceProvider)
                  .next('students');
              final admissionNumber = formatAdmissionNumber(sequenceNumber);
              final admissionId = _ref
                  .read(studentAdmissionRepositoryProvider(uid))
                  .collection
                  .doc()
                  .id;

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
                      admissionNumber: admissionNumber,
                      name: name.trim(),
                      fatherName: fatherName.trim(),
                      dateOfBirth: dateOfBirth,
                      gender: gender,
                      photoUrl: _blankToNull(photoUrl),
                      address: address.trim(),
                      className: className.trim(),
                      board: boardDisplayName.trim(),
                      batchId: batchId,
                      academicSession: academicSessionName.trim(),
                      academicSessionId: academicSessionId,
                      classId: classId,
                      boardId: boardId,
                      boardCustomText: _blankToNull(boardCustomText),
                      primaryMobile: primaryMobile.trim(),
                      secondaryMobile: secondaryMobile?.trim(),
                      standardFee: standardFee,
                      finalFee: finalFee,
                      feeReason: feeReason?.trim(),
                      paymentPlan: paymentPlan,
                      admissionDate: now,
                      currentAdmissionId: admissionId,
                      active: true,
                      createdAt: now,
                      updatedAt: now,
                    ),
                  );
              await _ref
                  .read(studentAdmissionRepositoryProvider(uid))
                  .set(
                    admissionId,
                    StudentAdmission(
                      admissionId: admissionId,
                      studentUid: uid,
                      academicSessionId: academicSessionId,
                      classId: classId,
                      batchId: batchId,
                      boardId: boardId,
                      boardCustomText: _blankToNull(boardCustomText),
                      standardFee: standardFee,
                      finalFee: finalFee,
                      feeReason: feeReason?.trim(),
                      paymentPlan: paymentPlan,
                      installments: paymentPlan == PaymentPlan.installment
                          ? installments
                          : const [],
                      admissionDate: now,
                      active: true,
                      configuredByUid: configuredByUid,
                      createdAt: now,
                      updatedAt: now,
                    ),
                  );
              await _ref
                  .read(batchRepositoryProvider)
                  .updateFields(batchId, {
                    'studentCount': FieldValue.increment(1),
                    'updatedAt': Timestamp.now(),
                  });

              return AdmissionResult(
                accountId: normalizedId,
                admissionNumber: admissionNumber,
              );
            },
          );
    } catch (error) {
      throw StudentFormFailure(mapAccountCreationError(error));
    }
  }

  /// Edits a student's own identity/contact details and board. Never
  /// touches their login account beyond syncing `displayName`, and never
  /// touches academic session/class/batch/fee - those only ever change
  /// via [changeBatch], which preserves the superseded admission record
  /// instead of overwriting it.
  Future<void> updateStudent({
    required StudentProfile existing,
    required String name,
    required String fatherName,
    required DateTime dateOfBirth,
    required Gender gender,
    String? photoUrl,
    required String address,
    required String primaryMobile,
    required String? secondaryMobile,
    String? boardId,
    String? boardCustomText,
    required String boardDisplayName,
  }) async {
    try {
      await _ref
          .read(studentRepositoryProvider)
          .set(
            existing.uid,
            StudentProfile(
              uid: existing.uid,
              accountId: existing.accountId,
              admissionNumber: existing.admissionNumber,
              name: name.trim(),
              fatherName: fatherName.trim(),
              dateOfBirth: dateOfBirth,
              gender: gender,
              photoUrl: _blankToNull(photoUrl),
              address: address.trim(),
              className: existing.className,
              board: boardDisplayName.trim(),
              batchId: existing.batchId,
              academicSession: existing.academicSession,
              academicSessionId: existing.academicSessionId,
              classId: existing.classId,
              boardId: boardId,
              boardCustomText: _blankToNull(boardCustomText),
              primaryMobile: primaryMobile.trim(),
              secondaryMobile: secondaryMobile?.trim(),
              standardFee: existing.standardFee,
              finalFee: existing.finalFee,
              feeReason: existing.feeReason,
              paymentPlan: existing.paymentPlan,
              admissionDate: existing.admissionDate,
              currentAdmissionId: existing.currentAdmissionId,
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

  /// Moves [existing] to a different session/class/batch/board/fee
  /// agreement: records a brand-new [StudentAdmission] (its own
  /// standard/final fee snapshot, remark and installment schedule),
  /// marks the previous admission `active: false` without altering its
  /// stored figures, and adjusts both batches' `studentCount`. The
  /// student's own identity and payment history are untouched.
  Future<void> changeBatch({
    required StudentProfile existing,
    required String academicSessionId,
    required String academicSessionName,
    required String classId,
    required String className,
    required String batchId,
    String? boardId,
    String? boardCustomText,
    required String boardDisplayName,
    required double standardFee,
    required double finalFee,
    required String? feeReason,
    required PaymentPlan paymentPlan,
    required List<InstallmentScheduleItem> installments,
    required String configuredByUid,
  }) async {
    try {
      final now = DateTime.now();
      final admissionRepo = _ref.read(
        studentAdmissionRepositoryProvider(existing.uid),
      );
      final newAdmissionId = admissionRepo.collection.doc().id;

      if (existing.currentAdmissionId.isNotEmpty) {
        await admissionRepo.updateFields(existing.currentAdmissionId, {
          'active': false,
          'updatedAt': Timestamp.now(),
        });
      }

      await admissionRepo.set(
        newAdmissionId,
        StudentAdmission(
          admissionId: newAdmissionId,
          studentUid: existing.uid,
          academicSessionId: academicSessionId,
          classId: classId,
          batchId: batchId,
          boardId: boardId,
          boardCustomText: _blankToNull(boardCustomText),
          standardFee: standardFee,
          finalFee: finalFee,
          feeReason: feeReason?.trim(),
          paymentPlan: paymentPlan,
          installments: paymentPlan == PaymentPlan.installment
              ? installments
              : const [],
          admissionDate: now,
          active: true,
          configuredByUid: configuredByUid,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await _ref
          .read(studentRepositoryProvider)
          .set(
            existing.uid,
            StudentProfile(
              uid: existing.uid,
              accountId: existing.accountId,
              admissionNumber: existing.admissionNumber,
              name: existing.name,
              fatherName: existing.fatherName,
              dateOfBirth: existing.dateOfBirth,
              gender: existing.gender,
              photoUrl: existing.photoUrl,
              address: existing.address,
              className: className.trim(),
              board: boardDisplayName.trim(),
              batchId: batchId,
              academicSession: academicSessionName.trim(),
              academicSessionId: academicSessionId,
              classId: classId,
              boardId: boardId,
              boardCustomText: _blankToNull(boardCustomText),
              primaryMobile: existing.primaryMobile,
              secondaryMobile: existing.secondaryMobile,
              standardFee: standardFee,
              finalFee: finalFee,
              feeReason: feeReason?.trim(),
              paymentPlan: paymentPlan,
              admissionDate: now,
              currentAdmissionId: newAdmissionId,
              active: existing.active,
              createdAt: existing.createdAt,
              updatedAt: now,
            ),
          );

      if (existing.batchId != batchId) {
        if (existing.batchId.isNotEmpty) {
          await _ref
              .read(batchRepositoryProvider)
              .updateFields(existing.batchId, {
                'studentCount': FieldValue.increment(-1),
                'updatedAt': Timestamp.now(),
              });
        }
        await _ref
            .read(batchRepositoryProvider)
            .updateFields(batchId, {
              'studentCount': FieldValue.increment(1),
              'updatedAt': Timestamp.now(),
            });
      }
    } catch (_) {
      throw const StudentFormFailure(
        "Could not change the student's batch. Please try again.",
      );
    }
  }

  /// Activates/deactivates both the student record and their login
  /// account together, so a deactivated student can no longer start a
  /// new session (see `selfSessionUpdateIsValid` in firestore.rules) -
  /// their historical admission/payment records are never touched.
  Future<void> setActive(StudentProfile existing, bool active) async {
    try {
      final now = Timestamp.now();
      await _ref.read(studentRepositoryProvider).updateFields(existing.uid, {
        'active': active,
        'updatedAt': now,
      });
      await _ref.read(userAccountRepositoryProvider).updateFields(
        existing.uid,
        {'active': active, 'updatedAt': now},
      );
    } catch (_) {
      throw const StudentFormFailure(
        'Could not update the student. Please try again.',
      );
    }
  }

  String? _blankToNull(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();
}
