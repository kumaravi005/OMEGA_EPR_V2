import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/core/utils/ranking.dart';

void main() {
  group('competitionRanks', () {
    test('assigns rank 1 to the highest score', () {
      expect(competitionRanks([70, 92, 55]), [2, 1, 3]);
    });

    test('ties share a rank, and the next distinct score skips ahead (92,92,88 -> 1,1,3)', () {
      expect(competitionRanks([92, 92, 88]), [1, 1, 3]);
    });

    test('handles every value tied', () {
      expect(competitionRanks([50, 50, 50]), [1, 1, 1]);
    });

    test('handles a single value', () {
      expect(competitionRanks([77]), [1]);
    });

    test('handles an empty list', () {
      expect(competitionRanks([]), <int>[]);
    });

    test('preserves input order rather than sorting the output', () {
      expect(competitionRanks([10, 90, 50]), [3, 1, 2]);
    });
  });
}
