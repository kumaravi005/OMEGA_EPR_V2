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

  /// Submitted by an unauthenticated visitor - no sign-in required
  /// (Set 5, extended Set 18 with Class/Board master-data references,
  /// both required here - an admission enquiry always names a class and
  /// board; see [submitCallbackRequest] for the lighter-weight form that
  /// needs neither).
  Future<void> submitEnquiry({
    required String name,
    required String? guardianName,
    required String classId,
    required String className,
    required String boardId,
    required String boardName,
    String? boardCustomText,
    required String primaryPhone,
    required String? secondaryPhone,
    required String? message,
  }) async {
    _validateCommon(
      name: name,
      primaryPhone: primaryPhone,
      secondaryPhone: secondaryPhone,
      message: message,
    );
    if (classId.trim().isEmpty) {
      throw const EnquiryFailure('Please select a class.');
    }
    if (boardId.trim().isEmpty) {
      throw const EnquiryFailure('Please select a board.');
    }

    try {
      final now = DateTime.now();
      await _ref.read(enquiryRepositoryProvider).add(
        Enquiry(
          enquiryId: '',
          name: name.trim(),
          guardianName: _blankToNull(guardianName),
          enquiryType: EnquiryType.admission,
          classId: classId,
          className: className,
          boardId: boardId,
          board: boardName,
          boardCustomText: _blankToNull(boardCustomText),
          primaryPhone: primaryPhone.trim(),
          secondaryPhone: _blankToNull(secondaryPhone),
          message: _blankToNull(message),
          status: EnquiryStatus.newEnquiry,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } catch (error) {
      if (error is EnquiryFailure) rethrow;
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

  /// Submitted by an unauthenticated visitor - no sign-in required. A
  /// callback request is deliberately lighter-weight than an admission
  /// enquiry (Set 18 section 15: "keep the public enquiry form simple")
  /// - name, phone, an optional message, nothing about class/board - so
  /// it writes into the SAME `enquiries` collection with
  /// `enquiryType: callback` rather than a second, unrelated database
  /// system. The older, separate `callbackRequests` collection (Set 5)
  /// is no longer written to going forward - see firestore.rules' doc
  /// comment on that collection - but stays readable for history.
  Future<void> submitCallbackRequest({
    required String name,
    required String phone,
    required String? message,
  }) async {
    _validateCommon(
      name: name,
      primaryPhone: phone,
      secondaryPhone: null,
      message: message,
    );

    try {
      final now = DateTime.now();
      await _ref.read(enquiryRepositoryProvider).add(
        Enquiry(
          enquiryId: '',
          name: name.trim(),
          guardianName: null,
          enquiryType: EnquiryType.callback,
          classId: null,
          className: null,
          boardId: null,
          board: null,
          boardCustomText: null,
          primaryPhone: phone.trim(),
          secondaryPhone: null,
          message: _blankToNull(message),
          status: EnquiryStatus.newEnquiry,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } catch (error) {
      if (error is EnquiryFailure) rethrow;
      throw const EnquiryFailure(
        'Could not submit your request. Please try again.',
      );
    }
  }

  /// Updates a LEGACY `callbackRequests` document (Set 5, pre-Set-18) -
  /// admin still needs to manage history collected before Set 18 moved
  /// new callback submissions into `enquiries`.
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

  void _validateCommon({
    required String name,
    required String primaryPhone,
    required String? secondaryPhone,
    required String? message,
  }) {
    if (name.trim().isEmpty) {
      throw const EnquiryFailure('Name is required.');
    }
    if (name.trim().length > 100) {
      throw const EnquiryFailure('Name is too long.');
    }
    if (primaryPhone.trim().isEmpty) {
      throw const EnquiryFailure('Primary phone number is required.');
    }
    final digitsOnly = primaryPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length < 10 || digitsOnly.length > 12) {
      throw const EnquiryFailure('Enter a valid primary phone number.');
    }
    if (secondaryPhone != null && secondaryPhone.trim().isNotEmpty) {
      final secondaryDigitsOnly = secondaryPhone.replaceAll(RegExp(r'[^0-9]'), '');
      if (secondaryDigitsOnly.length < 10 || secondaryDigitsOnly.length > 12) {
        throw const EnquiryFailure('Enter a valid secondary phone number.');
      }
    }
    if (message != null && message.trim().length > 1000) {
      throw const EnquiryFailure('Message is too long (1000 characters max).');
    }
  }

  String? _blankToNull(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();
}
