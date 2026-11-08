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

class FixedForecastEngine implements CyclePredictionEngine {
  FixedForecastEngine(this.length, {this.observed = false});
  final int length;
  final bool observed;

  @override
  String get name => 'fixed';
  @override
  bool get isActive => true;
  @override
  EngineOutput? predict(List<CycleRecord> history) => history.isEmpty
      ? null
      : EngineOutput(
          engineName: name,
          predictedDate: day(history.last.startDate, length),
          predictedLength: length.toDouble(),
          confidence: .8,
          windowDays: 2,
          observedStart: observed,
        );
}

void main() {
  test('experimental personalization is disabled by default', () {
    final history = historyFor([25, 28]);
    final fusion = ElaraFusion(engines: [FixedForecastEngine(30)]);
    final explicit = ElaraFusion(
      engines: [FixedForecastEngine(30)],
      experimentalPersonalization: false,
    );
    expect(fusion.experimentalPersonalization, isFalse);
    expect(fusion.predict(history)!.cycleLength, 30);
    expect(fusion.predict(history)!.predictedDate,
        explicit.predict(history)!.predictedDate);
  });

  test('opt-in blends a shrinkage estimate using only completed cycles', () {
    // median([25, 28]) = 26.5; (2 * 26.5 + 28) / 3 = 27.
    // 0.25 * 30 + 0.75 * 27 = 27.75, rounded to 28.
    final history = historyFor([25, 28]);
    final fusion = ElaraFusion(
      engines: [FixedForecastEngine(30)],
      experimentalPersonalization: true,
    );
    final result = fusion.predict(history)!;
    expect(result.cycleLength, 28);
    expect(result.predictedDate, day(history.last.startDate, 28));
    expect(result.confidence, closeTo(.64, 1e-12));
    expect(result.windowDays, 2);
    expect(result.contributingEngines.single.engineName, 'fixed');
  });

  test('a single completed cycle is handled using the same shrinkage rule', () {
    final history = historyFor([32]);
    final result = ElaraFusion(
      engines: [FixedForecastEngine(31)],
      experimentalPersonalization: true,
    ).predict(history)!;
    expect(result.cycleLength, 30);
  });

  test('a large adjustment is limited to three days', () {
    final history = historyFor([20, 20, 20]);
    final result = ElaraFusion(
      engines: [FixedForecastEngine(80)],
      experimentalPersonalization: true,
    ).predict(history)!;
    expect(result.cycleLength, 77);
    expect(result.predictedDate, day(history.last.startDate, 77));
  });

  test('an upward adjustment is also limited to three days', () {
    final history = historyFor([40, 40, 40]);
    final result = ElaraFusion(
      engines: [FixedForecastEngine(10)],
      experimentalPersonalization: true,
    ).predict(history)!;
    expect(result.cycleLength, 13);
    expect(result.predictedDate, day(history.last.startDate, 13));
  });

  test('empty history and a cold start remain unchanged', () {
    final fusion = ElaraFusion(experimentalPersonalization: true);
    expect(fusion.predict([]), isNull);
    final history = historyFor([]);
    final baseline = ElaraFusion().predict(history)!;
    final result = fusion.predict(history)!;
    expect(result.predictedDate, baseline.predictedDate);
    expect(result.windowDays, baseline.windowDays);
    expect(result.confidence, baseline.confidence);
  });

  test('confirmed observed starts override an experimental forecast', () {
    final history = historyFor([25, 28]);
    final result = ElaraFusion(
      engines: [FixedForecastEngine(24, observed: true)],
      experimentalPersonalization: true,
    ).predict(history)!;
    expect(result.isObserved, isTrue);
    expect(result.predictedDate, day(history.last.startDate, 24));
    expect(result.cycleLength, 24);
    expect(result.confidence, 1);
    expect(result.windowDays, 0);
  });

  test('long prior gaps and invalid histories retain engine safeguards', () {
    final fusion = ElaraFusion(experimentalPersonalization: true);
    final history = historyFor([100, 17, 80]);
    final baseline = ElaraFusion().predict(history)!;
    final result = fusion.predict(history)!;
    expect((result.cycleLength - baseline.cycleLength).abs(),
        lessThanOrEqualTo(3));
    expect(result.cycleLength, greaterThan(0));
    expect(result.windowDays, baseline.windowDays);
    expect(result.confidence, baseline.confidence);
    final duplicate = history.first;
    expect(() => fusion.predict([duplicate, duplicate]), throwsArgumentError);
  });
}
