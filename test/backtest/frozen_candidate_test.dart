// Copyright (c) 2026 Md. Mazidul Islam Mahim
// ELARA-core — Ensemble Menstrual Cycle Prediction Engine
// https://github.com/mahimmazidul/elara-core
//
// Original work by the author. Not derived from any ported engine.
// Licensed under Apache 2.0. See LICENSES/Apache-2.0.txt for details.
// The combined elara-core package is distributed under AGPL-3.0; see LICENSE.

import 'package:elara_core/elara_core.dart';
import 'package:test/test.dart';

import '../support.dart';
import 'frozen_candidate.dart';

void main() {
  test('frozen candidate preserves no-history and cold-start behavior', () {
    final candidate = FrozenCandidate();
    expect(candidate.predict([]), isNull);
    final history = historyFor([]);
    final baseline = historicalFusion().predict(history)!;
    final result = candidate.predict(history)!;
    expect(result.cycleLength, baseline.cycleLength);
    expect(result.predictedDate, baseline.predictedDate);
    expect(result.windowDays, baseline.windowDays);
    expect(result.confidence, baseline.confidence);
  });

  test('adjustment is bounded and preserves calendar and window consistency',
      () {
    final candidate = FrozenCandidate();
    for (final lengths in [
      [28, 28, 28],
      [26, 33, 29],
      [15, 98, 17],
      [80],
      [1],
    ]) {
      final history = historyFor(lengths);
      final before = historicalFusion().predict(history)!;
      final after = candidate.predict(history)!;
      expect(
          (after.cycleLength - before.cycleLength).abs(), lessThanOrEqualTo(3));
      expect(after.cycleLength, greaterThan(0));
      expect(
          after.predictedDate, day(history.last.startDate, after.cycleLength));
      expect(after.windowDays, before.windowDays);
      expect(after.confidence, before.confidence);
      expect(after.contributingEngines.map((e) => e.engineName),
          before.contributingEngines.map((e) => e.engineName));
    }
  });

  test('duplicate starts are rejected by the original engine contract', () {
    final start = DateTime.utc(2026, 1, 1);
    final history = [
      CycleRecord(startDate: start),
      CycleRecord(startDate: start)
    ];
    expect(() => FrozenCandidate().predict(history), throwsArgumentError);
  });
}
