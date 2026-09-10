import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/core/constants/app_constants.dart';

void main() {
  group('AppConstants.accountIdPattern', () {
    test('accepts valid account IDs', () {
      for (final id in ['stu001', 'teacher.raj', 'admin_1', 'a1b']) {
        expect(AppConstants.accountIdPattern.hasMatch(id), isTrue, reason: id);
      }
    });

    test('rejects invalid account IDs', () {
      for (final id in [
        'ab',
        '',
        'has space',
        'Upper',
        'user@id',
        '-startswithsymbol',
      ]) {
        expect(AppConstants.accountIdPattern.hasMatch(id), isFalse, reason: id);
      }
    });
  });
}
