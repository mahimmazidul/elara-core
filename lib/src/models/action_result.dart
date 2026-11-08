// Copyright (c) 2026 Md. Mazidul Islam Mahim
// ELARA-core — Ensemble Menstrual Cycle Prediction Engine
// https://github.com/mahimmazidul/elara-core
//
// Original work by the author. Not derived from any ported engine.
// Licensed under Apache 2.0. See LICENSES/Apache-2.0.txt for details.
// The combined elara-core package is distributed under AGPL-3.0; see LICENSE.

/// Suggestions are prompts for conversation, not claims about someone's mood.
class ActionCard {
  const ActionCard({required this.title, required this.body});

  final String title;
  final String body;
}

class ActionResult {
  ActionResult({
    required this.conversationScore,
    required this.romanceScore,
    required List<String> foodSuggestions,
    required List<ActionCard> cards,
  })  : foodSuggestions = List.unmodifiable(foodSuggestions),
        cards = List.unmodifiable(cards);

  final int conversationScore;
  final int romanceScore;
  final List<String> foodSuggestions;
  final List<ActionCard> cards;
}
