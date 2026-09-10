import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/core/utils/error_formatting.dart';

void main() {
  group('friendlyErrorText', () {
    test(
      'rewrites a permission-denied Firestore exception to plain language',
      () {
        final result = friendlyErrorText(
          'Could not load the gallery.\n[cloud_firestore/permission-denied] Missing or insufficient permissions.',
        );
        expect(result, isNot(contains('cloud_firestore')));
        expect(result, isNot(contains('permission-denied')));
        expect(result, contains("You don't have permission"));
        expect(result, startsWith('Could not load the gallery.'));
      },
    );

    test(
      'rewrites an unavailable/network error to a connection-check message',
      () {
        final result = friendlyErrorText(
          '[cloud_firestore/unavailable] The service is currently unavailable.',
        );
        expect(result, contains('check your connection'));
      },
    );

    test('falls back to a generic message for an unrecognized error code', () {
      final result = friendlyErrorText(
        '[firebase_auth/some-new-code] Something obscure happened.',
      );
      expect(result, contains('Something went wrong'));
    });

    test('leaves plain text with no Firebase-style tag unchanged', () {
      expect(
        friendlyErrorText('Student profile not found.'),
        'Student profile not found.',
      );
    });
  });
}
