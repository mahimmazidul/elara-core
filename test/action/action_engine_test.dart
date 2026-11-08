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
  final start = DateTime.utc(2025, 1, 1);
  final classifier = PhaseClassifier();
  final actions = ActionEngine();
  PhaseResult phase(int cycleDay, {int periodDuration = 5}) =>
      classifier.classify(
        lastPeriod:
            CycleRecord(startDate: start, periodDuration: periodDuration),
        cycleLength: 28,
        date: day(start, cycleDay - 1),
      );
  SeverityResult severity(double score) => SeverityResult(
        severityScore: score,
        baseSeverity: 0,
        modifier: score,
        hydrationMultiplier: 1,
        modifiersApplied: const {},
      );

  test('phase and day rules match the specified scores and food focus', () {
    final cases = <int, (int, int, String)>{
      1: (1, 2, 'Iron-rich foods'),
      2: (1, 2, 'Complex carbohydrates'),
      3: (3, 4, 'Leafy greens'),
      5: (3, 4, 'Dark chocolate'),
      6: (9, 7, 'A varied diet'),
      9: (10, 10, 'A light and fun meal'),
      16: (6, 5, 'Magnesium-rich foods'),
      22: (1, 2, 'Banana'),
    };
    for (final entry in cases.entries) {
      final result =
          actions.recommend(phase: phase(entry.key), severity: severity(0))!;
      expect(result.conversationScore, entry.value.$1);
      expect(result.romanceScore, entry.value.$2);
      expect(result.foodSuggestions, contains(entry.value.$3));
      expect(result.cards.first.body, contains('Ask'));
    }
  });

  test('high severity subtracts one, with a minimum of one', () {
    final below = actions.recommend(phase: phase(9), severity: severity(.6))!;
    final above =
        actions.recommend(phase: phase(9), severity: severity(.60001))!;
    expect((below.conversationScore, below.romanceScore), (10, 10));
    expect((above.conversationScore, above.romanceScore), (9, 9));
    final low = actions.recommend(phase: phase(1), severity: severity(.9))!;
    expect((low.conversationScore, low.romanceScore), (1, 1));
  });

  test('does not invent a rule for unknown phase or menstrual days beyond five',
      () {
    expect(actions.recommend(phase: phase(29), severity: severity(0)), isNull);
    expect(
        actions.recommend(
            phase: phase(6, periodDuration: 7), severity: severity(0)),
        isNull);
  });
}
