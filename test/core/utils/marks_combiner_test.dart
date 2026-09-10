import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/core/utils/marks_combiner.dart';

void main() {
  group('combineMarks', () {
    test('sums obtained marks and computes percentage against the combined max', () {
      final result = combineMarks([18.0, 22.0], [20.0, 30.0]);
      expect(result.total, 40.0);
      expect(result.percentage, closeTo(80.0, 0.0001)); // 40/50
    });

    test('a missing mark contributes 0 to the total but its max still counts', () {
      // Present: 18/20. Missing: null out of 30. Total possible stays 50.
      final result = combineMarks([18.0, null], [20.0, 30.0]);
      expect(result.total, 18.0);
      expect(result.percentage, closeTo(36.0, 0.0001)); // 18/50
    });

    test('percentage is null only when every max is zero', () {
      final result = combineMarks([null, null], [0.0, 0.0]);
      expect(result.total, 0.0);
      expect(result.percentage, isNull);
    });

    test('handles a single entry', () {
      final result = combineMarks([45.0], [50.0]);
      expect(result.total, 45.0);
      expect(result.percentage, closeTo(90.0, 0.0001));
    });
  });
}
