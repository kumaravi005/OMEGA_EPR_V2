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
