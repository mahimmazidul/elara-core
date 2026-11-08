import 'dart:convert';
import 'dart:io';

import 'package:elara_core/elara_core.dart';
import 'package:test/test.dart';

import '../support.dart';

DateTime? parseDay(Object? value) {
  if (value == null) return null;
  final parsed = DateTime.parse(value as String);
  return DateTime.utc(parsed.year, parsed.month, parsed.day);
}

List<DripCycleDay> fixtureCycle(Map<String, dynamic> fixtures, String name) {
  return (fixtures[name] as List<dynamic>).map((dynamic entry) {
    final row = entry as Map<String, dynamic>;
    return DripCycleDay(
      date: parseDay(row['date'])!,
      temperature: (row['temperature'] as num?)?.toDouble(),
      mucus: row['mucus'] as int?,
    );
  }).toList();
}

({List<BbtReading> bbt, List<MucusReading> mucus}) goodReadings(
    DateTime start) {
  final temperatures = [36.4, 36.4, 36.4, 36.4, 36.4, 36.4, 36.8, 36.8, 36.8];
  final qualities = [0, 0, 0, 2, 3, 4, 2, 1, 0];
  return (
    bbt: [
      for (var i = 0; i < temperatures.length; i++)
        BbtReading(date: day(start, i), celsius: temperatures[i])
    ],
    mucus: [
      for (var i = 0; i < qualities.length; i++)
        MucusReading(date: day(start, i), quality: qualities[i])
    ],
  );
}

void main() {
  final raw =
      jsonDecode(File('test/fixtures/sympto_parity.json').readAsStringSync())
          as Map<String, dynamic>;
  final fixtures = raw['fixtures'] as Map<String, dynamic>;
  final scenarios = raw['scenarios'] as List<dynamic>;
  group('sympto 3.0.2 upstream fixture parity', () {
    for (final dynamic item in scenarios) {
      final scenario = item as Map<String, dynamic>;
      test(scenario['label'] as String, () {
        final current = fixtureCycle(fixtures, scenario['cycle'] as String);
        final previousName = scenario['previous'] as String?;
        final earlier = (scenario['earlier'] as List<dynamic>)
            .map((dynamic name) => fixtureCycle(fixtures, name as String))
            .toList();
        final actual = SymptoThermalDetector().detect(
          current,
          previousCycle: previousName == null
              ? null
              : fixtureCycle(fixtures, previousName),
          earlierCycles: earlier,
        );
        final expected = scenario['expected'] as Map<String, dynamic>;
        expect(actual.preOvulatoryPhase?.start, parseDay(expected['preStart']));
        expect(actual.preOvulatoryPhase?.end, parseDay(expected['preEnd']));
        expect(actual.periOvulatoryStart, parseDay(expected['periStart']));
        expect(actual.fertilePhase?.end, parseDay(expected['periEnd']));
        expect(actual.postOvulatoryStart, parseDay(expected['postStart']));
        expect(actual.ovulationDetected, expected['firstHigh'] != null);
        if (actual.ovulationDetected) {
          expect(actual.temperatureShiftDay, parseDay(expected['firstHigh']));
          expect(actual.temperatureEvaluationComplete,
              parseDay(expected['tempEnd']));
          expect(actual.temperatureRule, expected['rule']);
          expect(actual.coverLine,
              closeTo((expected['coverLine'] as num).toDouble(), 1e-10));
          expect(actual.mucusPeakDay, parseDay(expected['mucusPeak']));
          expect(
              actual.mucusEvaluationComplete, parseDay(expected['mucusEnd']));
        }
      });
    }
  });

  group('temperature rules', () {
    final start = DateTime.utc(2025, 1, 1);
    DripDetectionResult detectTemperatures(List<double> temperatures) {
      return SymptoThermalDetector().detect([
        for (var i = 0; i < temperatures.length; i++)
          DripCycleDay(date: day(start, i), temperature: temperatures[i]),
      ]);
    }

    test('regular shift requires six prior readings and the 0.2 degree rise',
        () {
      final result = detectTemperatures(
          [36.7, 36.57, 36.47, 36.49, 36.57, 36.62, 36.55, 36.8, 36.86, 36.8]);
      expect(result.temperatureRule, 0);
      expect(result.coverLine, closeTo(36.6, 1e-9));
      expect(result.temperatureShiftDay, day(start, 7));
      expect(result.temperatureEvaluationComplete, day(start, 9));
      expect(result.ovulationDetected, isFalse); // no mucus confirmation
    });

    test('first and second temperature exceptions match upstream', () {
      final first = detectTemperatures([
        36.7,
        36.57,
        36.47,
        36.49,
        36.57,
        36.62,
        36.55,
        36.8,
        36.86,
        36.77,
        36.63
      ]);
      final second = detectTemperatures([
        36.7,
        36.57,
        36.47,
        36.49,
        36.57,
        36.62,
        36.55,
        36.8,
        36.86,
        36.6,
        36.8
      ]);
      expect(first.temperatureRule, 1);
      expect(second.temperatureRule, 2);
      expect(first.temperatureEvaluationComplete, day(start, 10));
      expect(second.temperatureEvaluationComplete, day(start, 10));
    });

    test('does not infer a shift from fewer than six earlier readings', () {
      expect(
          detectTemperatures([36.4, 36.4, 36.4, 36.4, 36.4, 36.8, 36.8, 36.8])
              .temperatureShiftDay,
          isNull);
    });
  });

  group('dormancy and bridges', () {
    final start = DateTime.utc(2025, 1, 1);
    final history = [CycleRecord(startDate: start)];
    final readings = goodReadings(start);

    test('disabled or missing either series stays dormant', () {
      final disabled = DripEngine(bbt: readings.bbt, mucus: readings.mucus);
      expect(disabled.isActive, isFalse);
      expect(disabled.detect(history), isNull);
      expect(disabled.predict(history), isNull);
      final missing = DripEngine(
          config: const DripEngineConfig(enabled: true), bbt: readings.bbt);
      expect(missing.isActive, isFalse);
      expect(missing.predict(history), isNull);
    });

    test(
        'enabled observations can be analyzed without making a period forecast',
        () {
      final engine = DripEngine(
          config: const DripEngineConfig(enabled: true),
          bbt: readings.bbt,
          mucus: readings.mucus);
      final detection = engine.detect(history)!;
      expect(engine.isActive, isTrue);
      expect(detection.ovulationDetected, isTrue);
      expect(detection.temperatureShiftDay, day(start, 6));
      expect(detection.mucusPeakDay, day(start, 5));
      expect(detection.postOvulatoryStart, day(start, 8));
      expect(detection.confidence, 0.5);
      expect(engine.predict(history), isNull);
    });

    test('built-in bridge is separately opt-in and penalizes confidence', () {
      final engine = DripEngine(
        config: const DripEngineConfig(enabled: true, useBuiltInBridge: true),
        bbt: readings.bbt,
        mucus: readings.mucus,
      );
      final result = engine.predict(history)!;
      expect(result.predictedDate, day(start, 20));
      expect(result.predictedLength, 20);
      expect(result.confidence, 0.25);
      expect(result.windowDays, 4);
      expect(result.observedStart, isFalse);
    });

    test('a caller bridge takes precedence over the built-in bridge', () {
      final engine = DripEngine(
        config: const DripEngineConfig(enabled: true, useBuiltInBridge: true),
        bbt: readings.bbt,
        mucus: readings.mucus,
        periodBridge: (d) => EngineOutput(
          engineName: 'custom',
          predictedDate: day(d.cycleStartDate, 26),
          predictedLength: 26,
          confidence: 0.7,
          windowDays: 3,
        ),
      );
      expect(engine.predict(history)!.engineName, 'drip');
      expect(engine.predict(history)!.predictedLength, 26);
      expect(engine.predict(history)!.confidence, 0.7);
    });

    test('a caller bridge returning null does not fall back to the heuristic',
        () {
      final engine = DripEngine(
        config: const DripEngineConfig(enabled: true, useBuiltInBridge: true),
        bbt: readings.bbt,
        mucus: readings.mucus,
        periodBridge: (_) => null,
      );
      expect(engine.predict(history), isNull);
    });

    test('a bridge cannot manufacture an observed start or inconsistent length',
        () {
      DripEngine build({required bool observed, required int dateOffset}) =>
          DripEngine(
            config: const DripEngineConfig(enabled: true),
            bbt: readings.bbt,
            mucus: readings.mucus,
            periodBridge: (d) => EngineOutput(
              engineName: 'custom',
              predictedDate: day(d.cycleStartDate, dateOffset),
              predictedLength: 26,
              confidence: 0.5,
              windowDays: 2,
              observedStart: observed,
            ),
          );
      expect(() => build(observed: true, dateOffset: 26).predict(history),
          throwsStateError);
      expect(() => build(observed: false, dateOffset: 27).predict(history),
          throwsStateError);
    });

    test('empty or excluded data does not produce a shift or a forecast', () {
      final empty = DripEngine(
          config: const DripEngineConfig(enabled: true, useBuiltInBridge: true),
          bbt: [],
          mucus: []);
      expect(empty.isActive, isTrue);
      expect(empty.detect(history)!.ovulationDetected, isFalse);
      expect(empty.predict(history), isNull);
      final excluded = DripEngine(
        config: const DripEngineConfig(enabled: true, useBuiltInBridge: true),
        bbt: [
          for (final x in readings.bbt)
            BbtReading(date: x.date, celsius: x.celsius, excluded: true)
        ],
        mucus: readings.mucus,
      );
      expect(excluded.predict(history), isNull);
    });
  });

  test('NFP mucus mapping handles incomplete and invalid categories', () {
    expect(nfpMucusQuality(null, 2), isNull);
    expect(nfpMucusQuality(0, 1), 3);
    expect(nfpMucusQuality(3, 0), 4);
    expect(() => nfpMucusQuality(4, 0), throwsArgumentError);
    expect(() => MucusReading(date: DateTime.utc(2025), quality: 5),
        throwsArgumentError);
  });

  test('duplicate readings and unordered detector data are rejected', () {
    final start = DateTime.utc(2025, 1, 1);
    final bbt = BbtReading(date: start, celsius: 36.5);
    expect(() => DripEngine(bbt: [bbt, bbt]), throwsArgumentError);
    final later = DripCycleDay(date: day(start, 1));
    final earlier = DripCycleDay(date: start);
    expect(() => SymptoThermalDetector().detect([later, earlier]),
        throwsArgumentError);
    expect(() => SymptoThermalDetector().detect([]), throwsArgumentError);
  });
}
