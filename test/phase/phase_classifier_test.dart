import 'package:elara_core/elara_core.dart';
import 'package:test/test.dart';

import '../support.dart';

void main() {
  final start = DateTime.utc(2025, 1, 1);
  final period = CycleRecord(startDate: start);
  final classifier = PhaseClassifier();
  PhaseResult classify(int cycleDay, {CycleRecord? last, int length = 28}) =>
      classifier.classify(
        lastPeriod: last ?? period,
        cycleLength: length,
        date: day((last ?? period).startDate, cycleDay - 1),
      );

  test('each phase and phase-day boundary is deterministic and nonoverlapping',
      () {
    final expected = <int, (CyclePhase, int)>{
      1: (CyclePhase.menstrual, 1),
      5: (CyclePhase.menstrual, 5),
      6: (CyclePhase.follicular, 1),
      8: (CyclePhase.follicular, 3),
      9: (CyclePhase.ovulatory, 1),
      14: (CyclePhase.ovulatory, 6),
      15: (CyclePhase.ovulatory, 7),
      16: (CyclePhase.lutealEarly, 1),
      21: (CyclePhase.lutealEarly, 6),
      22: (CyclePhase.lutealLate, 1),
      28: (CyclePhase.lutealLate, 7),
    };
    for (final entry in expected.entries) {
      final actual = classify(entry.key);
      expect((actual.phase, actual.phaseDay), entry.value,
          reason: 'cycle day ${entry.key}');
    }
    expect(classify(16).lutealSubphase, LutealSubphase.early);
    expect(classify(22).lutealSubphase, LutealSubphase.late);
    expect(classify(9).lutealSubphase, isNull);
  });

  test('calculates fertile dates and signed day distances', () {
    final result = classify(9);
    expect(result.ovulationDay, 14);
    expect(result.fertileWindow.start, day(start, 8));
    expect(result.fertileWindow.end, day(start, 14));
    expect(result.isFertile, isTrue);
    expect(classify(8).isFertile, isFalse);
    expect(classify(15).isFertile, isTrue);
    expect(classify(16).isFertile, isFalse);
    expect(result.daysUntilPeriod, 20);
    expect(result.daysUntilOvulation, 5);
    expect(classify(16).daysUntilOvulation, -2);
  });

  test('does not invent a new period when a prediction is overdue', () {
    final due = classify(29);
    expect(due.phase, CyclePhase.unknown);
    expect(due.phaseDay, isNull);
    expect(due.daysUntilPeriod, 0);
    expect(classify(30).daysUntilPeriod, -1);
  });

  test('short cycles can overlap bleeding and the estimated fertile window',
      () {
    final result = classify(2, length: 21);
    expect(result.phase, CyclePhase.menstrual);
    expect(result.fertileWindow.start, day(start, 1));
    expect(result.isFertile, isTrue);
  });

  test('uses recorded period duration and clips short-cycle windows to day one',
      () {
    final longer = CycleRecord(startDate: start, periodDuration: 7);
    expect(classify(7, last: longer).phase, CyclePhase.menstrual);
    expect(classify(8, last: longer).phase, CyclePhase.follicular);
    expect(classify(1, length: 15).fertileWindow.start, start);
  });

  test('rejects impossible arguments', () {
    expect(
        () => classifier.classify(
            lastPeriod: period, cycleLength: 14, date: start),
        throwsArgumentError);
    expect(
        () => classifier.classify(
            lastPeriod: period, cycleLength: 28, date: day(start, -1)),
        throwsArgumentError);
    final tooLong = CycleRecord(startDate: start, periodDuration: 29);
    expect(
        () => classifier.classify(
            lastPeriod: tooLong, cycleLength: 28, date: start),
        throwsArgumentError);
    expect(() => CycleRecord(startDate: start, periodDuration: 0),
        throwsArgumentError);
  });
}
