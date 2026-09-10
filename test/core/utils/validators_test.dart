import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/core/utils/validators.dart';

void main() {
  group('Validators.required', () {
    test('rejects null and empty/whitespace values', () {
      expect(Validators.required(null), isNotNull);
      expect(Validators.required(''), isNotNull);
      expect(Validators.required('   '), isNotNull);
    });

    test('accepts a non-empty value', () {
      expect(Validators.required('Omega'), isNull);
    });
  });

  group('Validators.email', () {
    test('rejects missing or malformed addresses', () {
      expect(Validators.email(null), isNotNull);
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email('missing@domain'), isNotNull);
    });

    test('accepts a well-formed address', () {
      expect(Validators.email('teacher@omega.edu'), isNull);
    });
  });

  group('Validators.phone', () {
    test('rejects a missing number when required', () {
      expect(Validators.phone(null), isNotNull);
      expect(Validators.phone(''), isNotNull);
    });

    test('accepts a missing number when not required', () {
      expect(Validators.phone(null, isRequired: false), isNull);
      expect(Validators.phone('', isRequired: false), isNull);
    });

    test('rejects too few or too many digits', () {
      expect(Validators.phone('12345'), isNotNull);
      expect(Validators.phone('1234567890123'), isNotNull);
    });

    test('rejects letters', () {
      expect(Validators.phone('98765abcde'), isNotNull);
    });

    test('accepts a plain 10-digit mobile number', () {
      expect(Validators.phone('9876543210'), isNull);
    });

    test('accepts formatting: spaces, dashes, and a +91/0 prefix', () {
      expect(Validators.phone('98765 43210'), isNull);
      expect(Validators.phone('+91-9876543210'), isNull);
      expect(Validators.phone('09876543210'), isNull);
    });

    test('still validates format for an optional number that was typed in', () {
      expect(Validators.phone('123', isRequired: false), isNotNull);
    });
  });
}
