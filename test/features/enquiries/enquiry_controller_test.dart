import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/features/enquiries/application/enquiry_controller.dart';

void main() {
  group('EnquiryController.submitEnquiry validation', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('rejects an empty name', () {
      final controller = container.read(enquiryControllerProvider);
      expect(
        () => controller.submitEnquiry(
          name: '   ',
          guardianName: null,
          classId: 'class9',
          className: 'Class 9',
          boardId: 'cbse',
          boardName: 'CBSE',
          primaryPhone: '9876543210',
          secondaryPhone: null,
          message: null,
        ),
        throwsA(
          isA<EnquiryFailure>().having((f) => f.message, 'message', contains('Name')),
        ),
      );
    });

    test('rejects a name over 100 characters', () {
      final controller = container.read(enquiryControllerProvider);
      expect(
        () => controller.submitEnquiry(
          name: 'A' * 101,
          guardianName: null,
          classId: 'class9',
          className: 'Class 9',
          boardId: 'cbse',
          boardName: 'CBSE',
          primaryPhone: '9876543210',
          secondaryPhone: null,
          message: null,
        ),
        throwsA(
          isA<EnquiryFailure>().having((f) => f.message, 'message', contains('too long')),
        ),
      );
    });

    test('rejects an invalid primary phone number', () {
      final controller = container.read(enquiryControllerProvider);
      expect(
        () => controller.submitEnquiry(
          name: 'Test Student',
          guardianName: null,
          classId: 'class9',
          className: 'Class 9',
          boardId: 'cbse',
          boardName: 'CBSE',
          primaryPhone: '123',
          secondaryPhone: null,
          message: null,
        ),
        throwsA(
          isA<EnquiryFailure>().having((f) => f.message, 'message', contains('phone')),
        ),
      );
    });

    test('rejects an invalid secondary phone number when one is given', () {
      final controller = container.read(enquiryControllerProvider);
      expect(
        () => controller.submitEnquiry(
          name: 'Test Student',
          guardianName: null,
          classId: 'class9',
          className: 'Class 9',
          boardId: 'cbse',
          boardName: 'CBSE',
          primaryPhone: '9876543210',
          secondaryPhone: '42',
          message: null,
        ),
        throwsA(
          isA<EnquiryFailure>().having((f) => f.message, 'message', contains('secondary')),
        ),
      );
    });

    test('rejects a message over 1000 characters', () {
      final controller = container.read(enquiryControllerProvider);
      expect(
        () => controller.submitEnquiry(
          name: 'Test Student',
          guardianName: null,
          classId: 'class9',
          className: 'Class 9',
          boardId: 'cbse',
          boardName: 'CBSE',
          primaryPhone: '9876543210',
          secondaryPhone: null,
          message: 'A' * 1001,
        ),
        throwsA(
          isA<EnquiryFailure>().having((f) => f.message, 'message', contains('too long')),
        ),
      );
    });

    test('rejects a missing class', () {
      final controller = container.read(enquiryControllerProvider);
      expect(
        () => controller.submitEnquiry(
          name: 'Test Student',
          guardianName: null,
          classId: '',
          className: 'Class 9',
          boardId: 'cbse',
          boardName: 'CBSE',
          primaryPhone: '9876543210',
          secondaryPhone: null,
          message: null,
        ),
        throwsA(
          isA<EnquiryFailure>().having((f) => f.message, 'message', contains('class')),
        ),
      );
    });

    test('rejects a missing board', () {
      final controller = container.read(enquiryControllerProvider);
      expect(
        () => controller.submitEnquiry(
          name: 'Test Student',
          guardianName: null,
          classId: 'class9',
          className: 'Class 9',
          boardId: '',
          boardName: 'CBSE',
          primaryPhone: '9876543210',
          secondaryPhone: null,
          message: null,
        ),
        throwsA(
          isA<EnquiryFailure>().having((f) => f.message, 'message', contains('board')),
        ),
      );
    });

    test('a well-formed admission enquiry passes validation up to the network call', () {
      final controller = container.read(enquiryControllerProvider);
      // Every validation rule passes here - the only remaining failure (no
      // Firebase app initialized in this bare test container) is the
      // generic submission failure, proving none of the earlier checks
      // rejected it.
      expect(
        () => controller.submitEnquiry(
          name: 'Test Student',
          guardianName: 'Test Guardian',
          classId: 'class9',
          className: 'Class 9',
          boardId: 'cbse',
          boardName: 'CBSE',
          primaryPhone: '9876543210',
          secondaryPhone: '9876500000',
          message: 'Please call back',
        ),
        throwsA(
          isA<EnquiryFailure>().having(
            (f) => f.message,
            'message',
            isNot(anyOf(contains('Name'), contains('phone'), contains('class'), contains('board'))),
          ),
        ),
      );
    });
  });

  group('EnquiryController.submitCallbackRequest validation', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('does not require a class or board - only name and phone', () {
      final controller = container.read(enquiryControllerProvider);
      expect(
        () => controller.submitCallbackRequest(
          name: 'Test Student',
          phone: '9876543210',
          message: null,
        ),
        throwsA(
          isA<EnquiryFailure>().having(
            (f) => f.message,
            'message',
            isNot(anyOf(contains('class'), contains('board'))),
          ),
        ),
      );
    });

    test('still rejects an empty name', () {
      final controller = container.read(enquiryControllerProvider);
      expect(
        () => controller.submitCallbackRequest(
          name: '  ',
          phone: '9876543210',
          message: null,
        ),
        throwsA(
          isA<EnquiryFailure>().having((f) => f.message, 'message', contains('Name')),
        ),
      );
    });

    test('still rejects an invalid phone number', () {
      final controller = container.read(enquiryControllerProvider);
      expect(
        () => controller.submitCallbackRequest(
          name: 'Test Student',
          phone: '42',
          message: null,
        ),
        throwsA(
          isA<EnquiryFailure>().having((f) => f.message, 'message', contains('phone')),
        ),
      );
    });
  });
}
