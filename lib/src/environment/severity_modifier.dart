// Copyright (c) 2026 Md. Mazidul Islam Mahim
// ELARA-core — Ensemble Menstrual Cycle Prediction Engine
// https://github.com/mahimmazidul/elara-core
//
// Original work by the author. Not derived from any ported engine.
// Licensed under Apache 2.0. See LICENSES/Apache-2.0.txt for details.
// The combined elara-core package is distributed under AGPL-3.0; see LICENSE.

import '../models/severity_result.dart';

enum Season { winter, preMonsoon, monsoon, postMonsoon }

/// Local observations supplied by the caller; the package never fetches them.
class EnvironmentConditions {
  EnvironmentConditions({
    required this.heatIndex,
    required this.pm25,
    required this.aqiCategory,
    required this.sunshineHours,
    required this.season,
    required this.hydrationLevel,
    this.humidityPercent,
  }) {
    if (!heatIndex.isFinite) throw ArgumentError.value(heatIndex, 'heatIndex');
    if (!pm25.isFinite || pm25 < 0) throw ArgumentError.value(pm25, 'pm25');
    if (aqiCategory < 1 || aqiCategory > 5) {
      throw ArgumentError.value(aqiCategory, 'aqiCategory', 'must be 1 to 5');
    }
    if (!sunshineHours.isFinite || sunshineHours < 0 || sunshineHours > 24) {
      throw ArgumentError.value(
          sunshineHours, 'sunshineHours', 'must be 0 to 24');
    }
    if (hydrationLevel < 1 || hydrationLevel > 3) {
      throw ArgumentError.value(
          hydrationLevel, 'hydrationLevel', 'must be 1 to 3');
    }
    final humidity = humidityPercent;
    if (humidity != null &&
        (!humidity.isFinite || humidity < 0 || humidity > 100)) {
      throw ArgumentError.value(
          humidity, 'humidityPercent', 'must be 0 to 100');
    }
  }

  final double heatIndex;
  final double pm25;
  final int aqiCategory;
  final double sunshineHours;
  final Season season;
  final int hydrationLevel;
  final double? humidityPercent;
}

class SeverityModifier {
  /// [baseSeverity] defaults to zero. Supplying a separate baseline lets the
  /// action engine's >0.6 rule be reached; climate alone is capped at +0.5.
  SeverityResult calculate(EnvironmentConditions conditions,
      {double baseSeverity = 0.0}) {
    if (!baseSeverity.isFinite || baseSeverity < 0 || baseSeverity > 1) {
      throw ArgumentError.value(
          baseSeverity, 'baseSeverity', 'must be between 0 and 1');
    }
    final heat = conditions.heatIndex > 42
        ? 0.20
        : conditions.heatIndex > 38
            ? 0.10
            : conditions.heatIndex > 35
                ? 0.05
                : 0.0;
    final pollution = conditions.pm25 > 150
        ? 0.15
        : conditions.pm25 > 100
            ? 0.10
            : conditions.pm25 > 55
                ? 0.05
                : 0.0;
    final sun = conditions.sunshineHours < 3
        ? 0.05
        : conditions.sunshineHours > 8
            ? -0.05
            : 0.0;
    final season = switch (conditions.season) {
      Season.preMonsoon => 0.08,
      Season.winter => 0.03,
      Season.monsoon || Season.postMonsoon => 0.0,
    };
    final factors = <String, double>{
      'heatIndex': heat,
      'pm25': pollution,
      'sunshine': sun,
      'season': season,
    };
    // AQI category and humidity are recorded inputs, but no coefficient was
    // specified for them. Don't invent one or double-count the heat index.
    final multiplier =
        conditions.hydrationLevel == 1 && conditions.heatIndex > 35
            ? 1.55
            : 1.0;
    final raw = factors.values.fold<double>(0, (sum, value) => sum + value) *
        multiplier;
    final modifier = raw.clamp(-0.3, 0.5);
    return SeverityResult(
      severityScore: baseSeverity + modifier,
      baseSeverity: baseSeverity,
      modifier: modifier,
      hydrationMultiplier: multiplier,
      modifiersApplied: factors,
    );
  }
}
