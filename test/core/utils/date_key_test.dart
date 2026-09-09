import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/core/utils/date_key.dart';

void main() {
  group('dateKey', () {
    test('formats as YYYY-MM-DD with zero-padding', () {
      expect(dateKey(DateTime(2026, 9, 5)), '2026-09-05');
      expect(dateKey(DateTime(2026, 12, 25)), '2026-12-25');
    });

    test('is stable regardless of time-of-day component', () {
      expect(dateKey(DateTime(2026, 9, 5, 23, 59)), dateKey(DateTime(2026, 9, 5, 0, 1)));
    });
  });

  group('dateOnly', () {
    test('strips the time component', () {
      final result = dateOnly(DateTime(2026, 9, 5, 14, 30, 15));
      expect(result, DateTime(2026, 9, 5));
    });
  });
}
