import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/callback_request.dart';
import '../data/enquiry.dart';
import '../data/enquiry_repository.dart';

class EnquiryFailure implements Exception {
  const EnquiryFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

final enquiryControllerProvider = Provider<EnquiryController>(
  (ref) => EnquiryController(ref),
);

class EnquiryController {
  EnquiryController(this._ref);

  final Ref _ref;

  /// Submitted by an unauthenticated visitor - no sign-in required.
  Future<void> submitEnquiry({
    required String name,
    required String? guardianName,
    required String? className,
    required String? board,
    required String primaryPhone,
    required String? secondaryPhone,
    required String? message,
  }) async {
    try {
      final now = DateTime.now();
      await _ref
          .read(enquiryRepositoryProvider)
          .add(
            Enquiry(
              enquiryId: '',
              name: name.trim(),
              guardianName: _blankToNull(guardianName),
              className: _blankToNull(className),
              board: _blankToNull(board),
              primaryPhone: primaryPhone.trim(),
              secondaryPhone: _blankToNull(secondaryPhone),
              message: _blankToNull(message),
              status: EnquiryStatus.newEnquiry,
              createdAt: now,
              updatedAt: now,
            ),
          );
    } catch (_) {
      throw const EnquiryFailure(
        'Could not submit your enquiry. Please try again.',
      );
    }
  }

  Future<void> updateStatus(Enquiry existing, EnquiryStatus status) async {
    try {
      await _ref.read(enquiryRepositoryProvider).updateFields(
        existing.enquiryId,
        {'status': status.name, 'updatedAt': Timestamp.now()},
      );
    } catch (_) {
      throw const EnquiryFailure(
        'Could not update the enquiry. Please try again.',
      );
    }
  }

  /// Submitted by an unauthenticated visitor - no sign-in required.
  Future<void> submitCallbackRequest({
    required String name,
    required String phone,
    required String? message,
  }) async {
    try {
      final now = DateTime.now();
      await _ref
          .read(callbackRequestRepositoryProvider)
          .add(
            CallbackRequest(
              requestId: '',
              name: name.trim(),
              phone: phone.trim(),
              message: _blankToNull(message),
              status: CallbackStatus.newRequest,
              createdAt: now,
              updatedAt: now,
            ),
          );
    } catch (_) {
      throw const EnquiryFailure(
        'Could not submit your request. Please try again.',
      );
    }
  }

  Future<void> updateCallbackStatus(
    CallbackRequest existing,
    CallbackStatus status,
  ) async {
    try {
      await _ref.read(callbackRequestRepositoryProvider).updateFields(
        existing.requestId,
        {'status': status.name, 'updatedAt': Timestamp.now()},
      );
    } catch (_) {
      throw const EnquiryFailure(
        'Could not update the request. Please try again.',
      );
    }
  }

  String? _blankToNull(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();
}
