/// Standard competition ranking ("1224 ranking"): equal scores share the
/// same rank, and the next distinct score's rank skips ahead by however
/// many tied it (92%, 92%, 88% -> ranks 1, 1, 3 - not 1, 1, 2).
///
/// Returns one rank per input, in the same order as [percentages] (not
/// sorted) - the caller decides how to sort/display rows; this only
/// answers "what rank does this score get".
List<int> competitionRanks(List<double> percentages) {
  final sortedDesc = [...percentages]..sort((a, b) => b.compareTo(a));
  final ranks = <double, int>{};
  for (var i = 0; i < sortedDesc.length; i++) {
    ranks.putIfAbsent(sortedDesc[i], () => i + 1);
  }
  return [for (final p in percentages) ranks[p]!];
}

/// [competitionRanks], but null-aware: a `null` percentage (no result,
/// absent, or an incomplete combined result - see
/// `features/results/data/result_calculator.dart`) is excluded from
/// ranking entirely rather than tying for the lowest rank, and gets
/// `null` back rather than a misleading number (Set 15 spec: "incomplete/
/// absent results should not receive a misleading rank").
List<int?> rankByPercentage(List<double?> percentages) {
  final ranked = percentages.whereType<double>().toList();
  final sortedDesc = [...ranked]..sort((a, b) => b.compareTo(a));
  final competition = competitionRanks(sortedDesc);
  final rankByValue = <double, int>{};
  for (var i = 0; i < sortedDesc.length; i++) {
    rankByValue.putIfAbsent(sortedDesc[i], () => competition[i]);
  }
  return [for (final p in percentages) p == null ? null : rankByValue[p]];
}
