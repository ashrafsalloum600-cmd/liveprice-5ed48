import 'package:liveprice/models/product_model.dart';
import 'package:liveprice/services/inventory_parser.dart';

class InventoryMatchSuggestion {
  const InventoryMatchSuggestion({required this.product, required this.score});

  final ProductModel product;
  final int score;
}

class InventoryMatcher {
  static Map<String, ProductModel> uniqueExactMatches(List<ProductModel> products) {
    final matches = <String, ProductModel>{};
    final ambiguousKeys = <String>{};
    for (final product in products) {
      final key = normalizedName(product.name);
      if (key.isEmpty) continue;
      if (matches.containsKey(key)) {
        matches.remove(key);
        ambiguousKeys.add(key);
      } else if (!ambiguousKeys.contains(key)) {
        matches[key] = product;
      }
    }
    return matches;
  }

  static String normalizedName(String value) {
    final normalized = normalizeName(value).toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]+'), ' ').trim();
    final tokens = normalized.isEmpty ? <String>[] : normalized.split(RegExp(r'\s+'));
    tokens.sort();
    return tokens.join(' ');
  }

  static List<InventoryMatchSuggestion> suggestionsFor(InventoryRow row, List<ProductModel> products, {int limit = 3}) {
    final sourceName = normalizedName(row.name);
    if (sourceName.isEmpty) return const [];

    final suggestions = <InventoryMatchSuggestion>[];
    for (final product in products) {
      final productName = normalizedName(product.name);
      if (productName.isEmpty) continue;
      suggestions.add(InventoryMatchSuggestion(product: product, score: _score(sourceName, productName)));
    }
    suggestions.sort((left, right) {
      final byScore = right.score.compareTo(left.score);
      return byScore != 0 ? byScore : left.product.name.compareTo(right.product.name);
    });
    return suggestions.take(limit).toList(growable: false);
  }

  static int _score(String left, String right) {
    if (left == right) return 100;
    final leftTokens = left.split(' ').toSet();
    final rightTokens = right.split(' ').toSet();
    final tokenIntersection = leftTokens.intersection(rightTokens).length;
    final tokenDice = 2 * tokenIntersection / (leftTokens.length + rightTokens.length);
    final leftRunes = left.runes.toList(growable: false);
    final rightRunes = right.runes.toList(growable: false);
    final longestLength = leftRunes.length > rightRunes.length ? leftRunes.length : rightRunes.length;
    final editSimilarity = longestLength == 0 ? 1.0 : 1 - _editDistance(leftRunes, rightRunes) / longestLength;
    return ((tokenDice * 0.4 + editSimilarity * 0.6) * 100).round().clamp(0, 100);
  }

  static int _editDistance(List<int> left, List<int> right) {
    var previous = List<int>.generate(right.length + 1, (index) => index);
    for (var leftIndex = 1; leftIndex <= left.length; leftIndex++) {
      final current = List<int>.filled(right.length + 1, 0);
      current[0] = leftIndex;
      for (var rightIndex = 1; rightIndex <= right.length; rightIndex++) {
        final substitutionCost = left[leftIndex - 1] == right[rightIndex - 1] ? 0 : 1;
        final deletion = previous[rightIndex] + 1;
        final insertion = current[rightIndex - 1] + 1;
        final substitution = previous[rightIndex - 1] + substitutionCost;
        current[rightIndex] = [deletion, insertion, substitution].reduce((a, b) => a < b ? a : b);
      }
      previous = current;
    }
    return previous[right.length];
  }
}
