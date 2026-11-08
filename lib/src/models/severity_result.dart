/// Environmental adjustment and its individual, unscaled contributions.
class SeverityResult {
  SeverityResult({
    required this.severityScore,
    required this.baseSeverity,
    required this.modifier,
    required this.hydrationMultiplier,
    required Map<String, double> modifiersApplied,
  }) : modifiersApplied = Map.unmodifiable(modifiersApplied);

  final double severityScore;
  final double baseSeverity;
  final double modifier;
  final double hydrationMultiplier;
  final Map<String, double> modifiersApplied;
}
