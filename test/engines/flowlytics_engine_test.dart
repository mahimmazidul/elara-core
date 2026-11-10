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
  group('Flowlytics enhanced predictor', () {
    test('weights the six most recent cycles for location and every gap for '
        'dispersion', () {
      final result =
          FlowlyticsEngine().predict(historyFor([20, 24, 28, 32, 36, 40, 44]))!;
      // Location: the six most recent intervals, recency-weighted.
      expect(result.predictedLength, 36);
      // Dispersion: all seven, as a sample standard deviation of 8.64 days.
      // The window used to be clamped to four days, which made a history that
      // varied by three weeks look like a two-day uncertainty.
      expect(result.windowDays, 9);
      expect(result.confidence, 0.30);
    });

    test('an interval outside the plausibility band widens the window instead '
        'of disappearing from it', () {
      final result = FlowlyticsEngine().predict(historyFor([14, 15, 50, 51]))!;
      // The band still guards the *mean*: 15 and 50 only.
      expect(result.predictedLength, 33);
      // But all four intervals are evidence of how variable this history is.
      // Dropping them from the spread is what used to make an irregular cycle
      // report a regular one.
      expect(result.windowDays, 21);
      expect(result.confidence, 0.30);
    });

    test('a history entirely outside the band predicts her cycle, not the '
        'baseline', () {
      // A person whose recorded cycles are all longer than the band has shown
      // that the band does not describe her. Answering with the 28-day default
      // was the documented long-cycle failure.
      final result = FlowlyticsEngine().predict(historyFor([55, 58, 57]))!;
      expect(result.predictedLength, 57);
      expect(result.windowDays, 2);
    });

    test('one long interval is uncertainty, not a deleted observation', () {
      final result =
          FlowlyticsEngine().predict(historyFor([28, 28, 28, 63]))!;
      // The mean stays on the three in-band cycles...
      expect(result.predictedLength, 28);
      // ...and the miss shows up where a user can act on it.
      expect(result.windowDays, greaterThan(10));
      expect(result.confidence, 0.30);
    });

    test('the window is capped at the span a calendar estimate can address',
        () {
      final result =
          FlowlyticsEngine().predict(historyFor([16, 50, 19, 49, 17, 48]))!;
      expect(result.windowDays, lessThanOrEqualTo(60));
    });

    test('uses baseline with one start; no clock-based empty-history forecast',
        () {
      final engine = FlowlyticsEngine(baselineCycle: 29);
      expect(engine.predict([]), isNull);
      final result = engine.predict(historyFor([]))!;
      expect(result.predictedLength, 29);
      expect(result.confidence, 0.40);
      expect(result.windowDays, 2);
    });

    test('confidence follows deviation and completed-cycle count', () {
      expect(FlowlyticsEngine().predict(historyFor([28, 28]))!.confidence, 0.4);
      final stable = FlowlyticsEngine().predict(historyFor([28, 28, 28]))!;
      expect(stable.confidence, 0.95);
      expect(stable.windowDays, 1);
    });

    test('all upstream regularity confidence bands are represented', () {
      // The bands are entered by a sample standard deviation (n-1), so a
      // three-cycle history needs a spread under a day for the top band.
      final cases = <(List<int>, double)>[
        ([28, 28, 29], .95),
        ([27, 28, 29], .85),
        ([26, 28, 30], .65),
        ([24, 28, 32], .45),
        ([18, 28, 38], .30),
      ];
      for (final c in cases) {
        expect(FlowlyticsEngine().predict(historyFor(c.$1))!.confidence, c.$2);
      }
    });

    test('secondary symptoms nudge by one day only in the navigator window',
        () {
      final history = historyFor([28, 28, 28]);
      final start = history.last.startDate;
      final near = FlowlyticsEngine(
          symptoms: FlowSymptoms(date: day(start, 23), moods: ['Tired']));
      expect(near.predict(history)!.predictedLength, 27);
      final early = FlowlyticsEngine(
          symptoms: FlowSymptoms(date: day(start, 15), skin: ['Oily']));
      expect(early.predict(history)!.predictedLength, 28);
    });

    test(
        'physical symptoms nudge by two days and spotting is not confirmed flow',
        () {
      final history = historyFor([28, 28, 28]);
      final start = history.last.startDate;
      final pain = FlowlyticsEngine(
          symptoms: FlowSymptoms(date: day(start, 25), physical: ['Cramps']));
      expect(pain.predict(history)!.predictedLength, 26);
      final spotting = FlowlyticsEngine(
              symptoms: FlowSymptoms(date: day(start, 25), spotting: true))
          .predict(history)!;
      expect(spotting.predictedLength, 25);
      expect(spotting.observedStart, isFalse);
    });

    test('confirmed new flow overrides the date, not an already recorded start',
        () {
      final history = historyFor([28, 28, 28]);
      final start = history.last.startDate;
      final flow = FlowlyticsEngine(
              symptoms:
                  FlowSymptoms(date: day(start, 24), confirmedFlowStart: true))
          .predict(history)!;
      expect(flow.predictedLength, 24);
      expect(flow.observedStart, isTrue);
      final ongoing = FlowlyticsEngine(
              symptoms: FlowSymptoms(date: start, confirmedFlowStart: true))
          .predict(history)!;
      expect(ongoing.predictedLength, 28);
      expect(ongoing.observedStart, isFalse);
    });

    test('validates the input contract', () {
      expect(() => FlowlyticsEngine(baselineCycle: 0), throwsArgumentError);
      final d = CycleRecord(startDate: DateTime.utc(2025, 1, 1));
      expect(() => FlowlyticsEngine().predict([d, d]), throwsArgumentError);
    });
  });
}
