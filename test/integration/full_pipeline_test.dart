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

void main() {
  test('history to ensemble to phase to climate-adjusted action works offline',
      () {
    final history = historyFor([28, 28, 28]);
    final prediction = ElaraFusion().predict(history)!;
    expect(prediction.contributingEngines.map((e) => e.engineName),
        ['OpenCiclo', 'Flowlytics']);
    final phase = PhaseClassifier().classify(
      lastPeriod: history.last,
      cycleLength: prediction.cycleLength,
      date: day(history.last.startDate, 3),
    );
    final severity = SeverityModifier().calculate(
      EnvironmentConditions(
        heatIndex: 43,
        pm25: 151,
        aqiCategory: 5,
        sunshineHours: 2,
        season: Season.preMonsoon,
        hydrationLevel: 1,
      ),
      baseSeverity: .2,
    );
    final action = ActionEngine().recommend(phase: phase, severity: severity)!;
    expect(phase.phase, CyclePhase.menstrual);
    expect(phase.phaseDay, 4);
    expect(severity.severityScore, closeTo(.7, 1e-12));
    expect((action.conversationScore, action.romanceScore), (2, 3));
  });

  test('calendar arithmetic ignores clock time and daylight-saving changes',
      () {
    final history = [
      CycleRecord(startDate: DateTime(2024, 3, 9, 23, 59)),
      CycleRecord(startDate: DateTime(2024, 4, 6, 0, 1)),
    ];
    final forecast = FlowlyticsEngine().predict(history)!;
    expect(forecast.predictedLength, 28);
    expect(history.last.startDate, DateTime.utc(2024, 4, 6));
    expect(forecast.predictedDate, DateTime.utc(2024, 5, 4));
  });

  test('a newly reported period start can be used to begin a new phase', () {
    final history = historyFor([28, 28, 28]);
    final observed = day(history.last.startDate, 25);
    final prediction = ElaraFusion(engines: [
      OpenCicloEngine(),
      FlowlyticsEngine(
          symptoms: FlowSymptoms(date: observed, confirmedFlowStart: true)),
    ]).predict(history)!;
    expect(prediction.isObserved, isTrue);
    final current = CycleRecord(startDate: prediction.predictedDate);
    final phase = PhaseClassifier().classify(
        lastPeriod: current,
        cycleLength: prediction.cycleLength,
        date: observed);
    expect((phase.phase, phase.phaseDay), (CyclePhase.menstrual, 1));
  });

  test('drip enters fusion only with data, enablement and a bridge', () {
    final history = historyFor([]);
    final start = history.last.startDate;
    final temperatures = [36.4, 36.4, 36.4, 36.4, 36.4, 36.4, 36.8, 36.8, 36.8];
    final qualities = [0, 0, 0, 2, 3, 4, 2, 1, 0];
    final bbt = [
      for (var i = 0; i < temperatures.length; i++)
        BbtReading(date: day(start, i), celsius: temperatures[i])
    ];
    final mucus = [
      for (var i = 0; i < qualities.length; i++)
        MucusReading(date: day(start, i), quality: qualities[i])
    ];
    PredictionResult run(DripEngine drip) =>
        ElaraFusion(engines: [OpenCicloEngine(), FlowlyticsEngine(), drip])
            .predict(history)!;
    final disabled = run(DripEngine(bbt: bbt, mucus: mucus));
    final noBridge = run(DripEngine(
        config: const DripEngineConfig(enabled: true), bbt: bbt, mucus: mucus));
    final bridged = run(DripEngine(
        config: const DripEngineConfig(enabled: true, useBuiltInBridge: true),
        bbt: bbt,
        mucus: mucus));
    expect(disabled.contributingEngines, hasLength(2));
    expect(noBridge.contributingEngines, hasLength(2));
    expect(bridged.contributingEngines, hasLength(3));
    expect(bridged.contributingEngines.last.engineName, 'drip');
    expect(bridged.cycleLength, lessThan(disabled.cycleLength));
  });
}
