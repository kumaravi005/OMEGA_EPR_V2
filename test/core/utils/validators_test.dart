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
}
