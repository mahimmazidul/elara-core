// Copyright (c) 2026 Md. Mazidul Islam Mahim
// ELARA-core — Ensemble Menstrual Cycle Prediction Engine
// https://github.com/mahimmazidul/elara-core
//
// Original work by the author. Not derived from any ported engine.
// Licensed under Apache 2.0. See LICENSES/Apache-2.0.txt for details.
// The combined elara-core package is distributed under AGPL-3.0; see LICENSE.

import 'package:elara_core/elara_core.dart';
import 'package:test/test.dart';

EnvironmentConditions conditions({
  double heat = 35,
  double pm = 0,
  double sun = 5,
  Season season = Season.monsoon,
  int hydration = 2,
  int aqi = 1,
  double? humidity,
}) =>
    EnvironmentConditions(
      heatIndex: heat,
      pm25: pm,
      aqiCategory: aqi,
      sunshineHours: sun,
      season: season,
      hydrationLevel: hydration,
      humidityPercent: humidity,
    );

void main() {
  final modifier = SeverityModifier();

  test('heat and PM thresholds are strict and mutually exclusive', () {
    double heat(double value) => modifier
        .calculate(conditions(heat: value))
        .modifiersApplied['heatIndex']!;
    expect(heat(35), 0);
    expect(heat(35.01), .05);
    expect(heat(38), .05);
    expect(heat(38.01), .10);
    expect(heat(42), .10);
    expect(heat(42.01), .20);
    double pm(double value) =>
        modifier.calculate(conditions(pm: value)).modifiersApplied['pm25']!;
    expect(pm(55), 0);
    expect(pm(55.01), .05);
    expect(pm(100), .05);
    expect(pm(100.01), .10);
    expect(pm(150), .10);
    expect(pm(150.01), .15);
  });

  test('sunshine and all seasons match the rule table', () {
    expect(modifier.calculate(conditions(sun: 2.99)).modifier,
        closeTo(.05, 1e-12));
    expect(modifier.calculate(conditions(sun: 3)).modifier, 0);
    expect(modifier.calculate(conditions(sun: 8)).modifier, 0);
    expect(modifier.calculate(conditions(sun: 8.01)).modifier,
        closeTo(-.05, 1e-12));
    expect(modifier.calculate(conditions(season: Season.preMonsoon)).modifier,
        closeTo(.08, 1e-12));
    expect(modifier.calculate(conditions(season: Season.winter)).modifier,
        closeTo(.03, 1e-12));
    expect(modifier.calculate(conditions(season: Season.monsoon)).modifier, 0);
    expect(
        modifier.calculate(conditions(season: Season.postMonsoon)).modifier, 0);
  });

  test('low hydration multiplies the entire modifier before clamping', () {
    final result = modifier.calculate(
        conditions(heat: 36, pm: 60, season: Season.preMonsoon, hydration: 1));
    expect(result.hydrationMultiplier, 1.55);
    expect(result.modifier, closeTo((.05 + .05 + .08) * 1.55, 1e-12));
    expect(
        modifier
            .calculate(conditions(heat: 35, hydration: 1))
            .hydrationMultiplier,
        1);
  });

  test('clamps the modifier, while an optional baseline is separate', () {
    final result = modifier.calculate(
        conditions(
            heat: 43, pm: 151, sun: 2, season: Season.preMonsoon, hydration: 1),
        baseSeverity: .2);
    expect(result.modifier, .5);
    expect(result.severityScore, closeTo(.7, 1e-12));
    expect(result.baseSeverity, .2);
  });

  test('AQI category and humidity do not invent unprovided coefficients', () {
    final a = modifier.calculate(conditions(aqi: 1, humidity: 10));
    final b = modifier.calculate(conditions(aqi: 5, humidity: 95));
    expect(a.modifier, b.modifier);
    expect(a.modifiersApplied, b.modifiersApplied);
  });

  test('rejects invalid environmental inputs', () {
    expect(() => conditions(aqi: 0), throwsArgumentError);
    expect(() => conditions(hydration: 4), throwsArgumentError);
    expect(() => conditions(pm: -1), throwsArgumentError);
    expect(() => conditions(sun: 25), throwsArgumentError);
    expect(() => conditions(humidity: 101), throwsArgumentError);
    expect(() => modifier.calculate(conditions(), baseSeverity: 1.1),
        throwsArgumentError);
  });
}
