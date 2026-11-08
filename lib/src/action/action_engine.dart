import 'dart:math' as math;

import '../models/action_result.dart';
import '../models/phase_result.dart';
import '../models/severity_result.dart';

/// A small rule table for optional prompts, not a way to infer a person's wishes.
class ActionEngine {
  /// Returns null when the phase is unknown or no menstrual-day rule is given.
  ActionResult? recommend(
      {required PhaseResult phase, required SeverityResult severity}) {
    final rule = switch (phase.phase) {
      CyclePhase.menstrual
          when phase.phaseDay != null && phase.phaseDay! <= 2 =>
        const _Rule(1, 2, ['Complex carbohydrates', 'Iron-rich foods'],
            'Offer practical support'),
      CyclePhase.menstrual
          when phase.phaseDay != null && phase.phaseDay! <= 5 =>
        const _Rule(
            3, 4, ['Leafy greens', 'Dark chocolate'], 'Check in gently'),
      CyclePhase.follicular =>
        const _Rule(9, 7, ['A varied diet'], 'Make time to connect'),
      CyclePhase.ovulatory =>
        const _Rule(10, 10, ['A light and fun meal'], 'Consider a date night'),
      CyclePhase.lutealEarly => const _Rule(
          6, 5, ['Magnesium-rich foods'], 'Make room for a quiet check-in'),
      CyclePhase.lutealLate => const _Rule(
          1,
          2,
          ['Carbohydrates', 'Turkey', 'Banana'],
          'Offer support without assumptions'),
      _ => null,
    };
    if (rule == null) return null;
    final adjustment = severity.severityScore > 0.6 ? 1 : 0;
    return ActionResult(
      conversationScore: math.max(1, rule.conversation - adjustment),
      romanceScore: math.max(1, rule.romance - adjustment),
      foodSuggestions: rule.food,
      cards: [
        ActionCard(
            title: rule.title,
            body: 'Ask what would feel welcome; preferences can change.'),
        ActionCard(title: 'Food idea', body: rule.food.join(', ')),
      ],
    );
  }
}

class _Rule {
  const _Rule(this.conversation, this.romance, this.food, this.title);
  final int conversation;
  final int romance;
  final List<String> food;
  final String title;
}
