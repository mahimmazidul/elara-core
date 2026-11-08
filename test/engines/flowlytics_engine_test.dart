import 'package:elara_core/elara_core.dart';
import 'package:test/test.dart';

import '../support.dart';

void main() {
  group('Flowlytics enhanced predictor', () {
    test(
        'uses only the six most recent weights but all valid gaps for deviation',
        () {
      final result =
          FlowlyticsEngine().predict(historyFor([20, 24, 28, 32, 36, 40, 44]))!;
      expect(result.predictedLength, 36);
      expect(result.confidence, 0.30);
      expect(result.windowDays, 4);
    });

    test('keeps 15 through 50 inclusive and ignores other intervals', () {
      final result = FlowlyticsEngine().predict(historyFor([14, 15, 50, 51]))!;
      expect(result.predictedLength, 33);
      expect(result.confidence, 0.40);
      expect(result.windowDays, 4);
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
      final cases = <(List<int>, double)>[
        ([27, 28, 29], .95),
        ([26, 28, 30], .85),
        ([24, 28, 32], .65),
        ([22, 28, 34], .45),
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
