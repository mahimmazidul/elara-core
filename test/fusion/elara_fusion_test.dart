import 'dart:math' as math;

import 'package:elara_core/elara_core.dart';
import 'package:test/test.dart';

import '../support.dart';

class FakeEngine implements CyclePredictionEngine {
  FakeEngine(this.name, this.output, {this.isActive = true});
  @override
  final String name;
  final EngineOutput? output;
  @override
  final bool isActive;
  @override
  EngineOutput? predict(List<CycleRecord> history) => output;
}

void main() {
  final history = historyFor([]);
  final start = history.last.startDate;
  EngineOutput output(String name, int length, double confidence, int window,
          {bool observed = false}) =>
      EngineOutput(
        engineName: name,
        predictedDate: day(start, length),
        predictedLength: length.toDouble(),
        confidence: confidence,
        windowDays: window,
        observedStart: observed,
      );

  test('no history, no active outputs, or zero total weight returns null', () {
    expect(ElaraFusion().predict([]), isNull);
    expect(
        ElaraFusion(engines: [
          FakeEngine('off', output('off', 28, .8, 2), isActive: false)
        ]).predict(history),
        isNull);
    expect(ElaraFusion(engines: [FakeEngine('none', null)]).predict(history),
        isNull);
    expect(
        ElaraFusion(engines: [FakeEngine('zero', output('zero', 28, 0, 2))])
            .predict(history),
        isNull);
  });

  test('one contributor keeps its date and window, with the 0.8 penalty', () {
    final result =
        ElaraFusion(engines: [FakeEngine('one', output('one', 27, .8, 3))])
            .predict(history)!;
    expect(result.predictedDate, day(start, 27));
    expect(result.cycleLength, 27);
    expect(result.windowDays, 3);
    expect(result.confidence, closeTo(.64, 1e-12));
  });

  test('uses confidence-weighted length and combines disagreement with windows',
      () {
    final result = ElaraFusion(engines: [
      FakeEngine('a', output('a', 26, .5, 2)),
      FakeEngine('b', output('b', 30, 1, 4)),
    ]).predict(history)!;
    expect(result.cycleLength, 29);
    expect(result.predictedDate, day(start, 29));
    final mean = (26 * .5 + 30) / 1.5;
    final variance =
        (.5 * math.pow(26 - mean, 2) + math.pow(30 - mean, 2)) / 1.5;
    final expectedConfidence = .75 / (1 + math.sqrt(variance) / 5);
    expect(result.confidence, closeTo(expectedConfidence, 1e-12));
    expect(result.windowDays, 4);
    expect(result.contributingEngines, hasLength(2));
  });

  test('disagreement widens the window and lowers the score', () {
    PredictionResult calc(int b) => ElaraFusion(engines: [
          FakeEngine('a', output('a', 28, .8, 2)),
          FakeEngine('b', output('b', b, .8, 2)),
        ]).predict(history)!;
    final agreeing = calc(28);
    final disagreeing = calc(38);
    expect(disagreeing.windowDays, greaterThan(agreeing.windowDays));
    expect(disagreeing.confidence, lessThan(agreeing.confidence));
  });

  test('zero-confidence engines do not count as consensus', () {
    final result = ElaraFusion(engines: [
      FakeEngine('a', output('a', 28, .8, 2)),
      FakeEngine('b', output('b', 40, 0, 8)),
    ]).predict(history)!;
    expect(result.cycleLength, 28);
    expect(result.confidence, closeTo(.64, 1e-12));
    expect(result.contributingEngines, hasLength(1));
  });

  test('a confirmed observed start wins over every forecast', () {
    final result = ElaraFusion(engines: [
      FakeEngine('forecast', output('forecast', 35, .99, 4)),
      FakeEngine('flow', output('flow', 24, .4, 2, observed: true)),
    ]).predict(history)!;
    expect(result.predictedDate, day(start, 24));
    expect(result.isObserved, isTrue);
    expect(result.confidence, 1);
    expect(result.windowDays, 0);
    expect(result.contributingEngines.single.engineName, 'flow');
  });

  test('conflicting observed starts and inconsistent outputs are rejected', () {
    final conflict = ElaraFusion(engines: [
      FakeEngine('a', output('a', 24, .5, 1, observed: true)),
      FakeEngine('b', output('b', 25, .5, 1, observed: true)),
    ]);
    expect(() => conflict.predict(history), throwsStateError);
    final bad = EngineOutput(
        engineName: 'bad',
        predictedDate: day(start, 29),
        predictedLength: 28,
        confidence: .5,
        windowDays: 1);
    expect(
        () => ElaraFusion(engines: [FakeEngine('bad', bad)]).predict(history),
        throwsStateError);
  });

  test('an output cannot represent less than one calendar day', () {
    expect(
      () => EngineOutput(
        engineName: 'bad',
        predictedDate: start,
        predictedLength: .4,
        confidence: .5,
        windowDays: 1,
      ),
      throwsArgumentError,
    );
  });

  test('confirmed Flowlytics observation overrides OpenCiclo in the ensemble',
      () {
    final longHistory = historyFor([28, 28, 28]);
    final observedDay = day(longHistory.last.startDate, 25);
    final fusion = ElaraFusion(engines: [
      OpenCicloEngine(),
      FlowlyticsEngine(
          symptoms: FlowSymptoms(date: observedDay, confirmedFlowStart: true)),
    ]);
    final result = fusion.predict(longHistory)!;
    expect(result.isObserved, isTrue);
    expect(result.predictedDate, observedDay);
  });
}
