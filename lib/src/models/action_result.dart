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
