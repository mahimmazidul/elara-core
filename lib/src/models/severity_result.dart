// Copyright (c) 2026 Md. Mazidul Islam Mahim
// ELARA-core — Ensemble Menstrual Cycle Prediction Engine
// https://github.com/mahimmazidul/elara-core
//
// Original work by the author. Not derived from any ported engine.
// Licensed under Apache 2.0. See LICENSES/Apache-2.0.txt for details.
// The combined elara-core package is distributed under AGPL-3.0; see LICENSE.

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
