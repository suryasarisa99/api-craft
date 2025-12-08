import 'package:flutter/services.dart';

final List<String> variables = [
  'baseUrl',
  'apiKey',
  'userId',
  'userName',
  'token',
];
final List<String> urls = [
  'https://api.example.com',
  'https://google.com',
  'http://localhost:3000',
  'https://test/{{token}}',
];
final List<String> functions = [
  'getData',
  'postData',
  'deleteItem',
  'updateUser',
];

class FillOptions {
  final String type; // 'url', 'variable', 'function'
  final List<List<int>> ranges; // Multiple [start, end] ranges
  final String label;
  final String value;
  final FuzzyMatch? fuzzyMatch;

  FillOptions({
    required this.type,
    required this.ranges,
    required this.label,
    required this.value,
    this.fuzzyMatch,
  });
}

// Match result for fuzzy search
class FuzzyMatch {
  final String text;
  final List<int> matchedIndices;
  final double score;

  FuzzyMatch({
    required this.text,
    required this.matchedIndices,
    required this.score,
  });
}

// Fuzzy search algorithm (VS Code style)
class FuzzySearch {
  static FuzzyMatch? match(String text, String query) {
    if (query.isEmpty) {
      return FuzzyMatch(text: text, matchedIndices: [], score: 0);
    }

    final textLower = text.toLowerCase();
    final queryLower = query.toLowerCase();

    List<int> matchedIndices = [];
    int textIndex = 0;
    int queryIndex = 0;
    int consecutiveMatches = 0;
    double score = 0;

    while (textIndex < textLower.length && queryIndex < queryLower.length) {
      if (textLower[textIndex] == queryLower[queryIndex]) {
        matchedIndices.add(textIndex);
        consecutiveMatches++;
        // Bonus for consecutive matches
        score += 1 + (consecutiveMatches * 0.5);
        // Bonus for matching at word boundaries
        if (textIndex == 0 ||
            text[textIndex - 1] == '_' ||
            text[textIndex - 1] == '-' ||
            text[textIndex].toUpperCase() == text[textIndex]) {
          score += 2;
        }
        queryIndex++;
      } else {
        consecutiveMatches = 0;
      }
      textIndex++;
    }

    // All query characters must match
    if (queryIndex != queryLower.length) {
      return null;
    }

    // Penalize matches that start later
    score -= matchedIndices.first * 0.1;

    return FuzzyMatch(text: text, matchedIndices: matchedIndices, score: score);
  }

  static List<FuzzyMatch> searchList(List<String> items, String query) {
    if (query.isEmpty) return [];

    List<FuzzyMatch> matches = [];
    for (var item in items) {
      final match = FuzzySearch.match(item, query);
      if (match != null) {
        matches.add(match);
      }
    }

    // Sort by score (highest first)
    matches.sort((a, b) => b.score.compareTo(a.score));
    return matches;
  }
}

class FilterService {
  static bool _isWordBoundary(String char) {
    return char == ' ' ||
        char == '\n' ||
        char == '\t' ||
        char == ',' ||
        char == ';' ||
        char == '/'; // Added / as word boundary
  }

  static bool _isAlpha(String char) {
    if (char.isEmpty) return false;
    final code = char.codeUnitAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }

  /// Detect what user is typing based on cursor position
  static Map<String, dynamic> detectTypingContext(TextEditingValue value) {
    final text = value.text;
    final cursorPos = value.selection.baseOffset;

    if (cursorPos <= 0 || text.isEmpty) {
      return {'type': 'none', 'query': '', 'start': 0, 'end': 0};
    }

    // Check if cursor is inside {{ }}
    int braceStart = -1;
    int braceEnd = -1;

    // Find surrounding braces (looking backwards from cursor)
    for (int i = cursorPos - 1; i >= 1; i--) {
      // If we hit a closing brace '}}' while looking backwards, it means
      // we are likely outside of any open block (e.g. {{prev}}/cur|rent)
      if (text[i] == '}' && text[i - 1] == '}') {
        break;
      }

      if (text[i - 1] == '{' && text[i] == '{') {
        braceStart = i - 1;
        break;
      }
    }

    // Find closing braces (looking forwards from cursor)
    for (int i = cursorPos; i < text.length - 1; i++) {
      if (text[i] == '}' && text[i + 1] == '}') {
        braceEnd = i + 2;
        break;
      }
    }

    // Inside braces
    if (braceStart != -1 && (braceEnd == -1 || braceEnd > cursorPos)) {
      final contentStart = braceStart + 2;
      final contentEnd = braceEnd != -1 ? braceEnd - 2 : cursorPos;
      final content = text.substring(contentStart, contentEnd);

      // Check if it's a function (contains '(')
      if (content.contains('(')) {
        final funcName = content.substring(0, content.indexOf('('));
        return {
          'type': 'function',
          'query': funcName,
          'start': braceStart,
          'end': braceEnd != -1 ? braceEnd : cursorPos,
          'insideBraces': true,
        };
      } else {
        return {
          'type': 'variable',
          'query': content,
          'start': braceStart,
          'end': braceEnd != -1 ? braceEnd : cursorPos,
          'insideBraces': true,
        };
      }
    }

    // Check for partial braces {{
    if (cursorPos >= 2 && text.substring(cursorPos - 2, cursorPos) == '{{') {
      return {
        'type': 'variable',
        'query': '',
        'start': cursorPos - 2,
        'end': cursorPos,
        'insideBraces': true,
      };
    }

    // Not in braces - find current word being typed
    int wordStart = cursorPos;
    while (wordStart > 0 && !_isWordBoundary(text[wordStart - 1])) {
      wordStart--;
    }

    int wordEnd = cursorPos;
    while (wordEnd < text.length && !_isWordBoundary(text[wordEnd])) {
      wordEnd++;
    }

    // --- SMART URL EXPANSION START ---
    // If the word boundary that stopped us was a '/', check if it's part of a protocol (e.g., https://)
    if (wordStart > 0 && text[wordStart - 1] == '/') {
      int expansionStart = wordStart;

      // Look back for '//' and possibly ':'
      while (expansionStart > 0 &&
          (text[expansionStart - 1] == '/' ||
              text[expansionStart - 1] == ':')) {
        expansionStart--;
      }

      // If we found '://' or similar, check if a protocol precedes it
      if (expansionStart < wordStart) {
        int protocolStart = expansionStart;
        while (protocolStart > 0 && _isAlpha(text[protocolStart - 1])) {
          protocolStart--;
        }

        final potentialProtocol = text.substring(protocolStart, expansionStart);
        if (potentialProtocol == 'http' || potentialProtocol == 'https') {
          // It is a valid URL protocol, expand the word start to include it
          wordStart = protocolStart;
        }
      }
    }
    // --- SMART URL EXPANSION END ---

    final word = text.substring(wordStart, wordEnd);

    if (word.isEmpty) {
      return {'type': 'none', 'query': '', 'start': 0, 'end': 0};
    }

    // Check if it looks like a URL (prioritize URL detection)
    if (word.contains('://') ||
        word.startsWith('http') ||
        word.startsWith('www')) {
      return {
        'type': 'url',
        'query': word,
        'start': wordStart,
        'end': wordEnd,
        'insideBraces': false,
      };
    }

    // Check if word contains parentheses (function without braces)
    if (word.contains('(')) {
      final funcName = word.substring(0, word.indexOf('('));
      return {
        'type': 'function',
        'query': funcName,
        'start': wordStart,
        'end': wordEnd,
        'insideBraces': false,
      };
    }

    // Try to match against all types and return the best match
    // This allows "google" to match URLs and "base" to match variables
    return {
      'type': 'multi', // Special type that will check all categories
      'query': word,
      'start': wordStart,
      'end': wordEnd,
      'insideBraces': false,
    };
  }

  static List<FillOptions> getOptions(TextEditingValue value) {
    final context = detectTypingContext(value);
    final String type = context['type'];
    final String query = context['query'];
    final int start = context['start'];
    final int end = context['end'];
    final bool insideBraces = context['insideBraces'] ?? false;

    if (type == 'none') {
      return [];
    }

    List<FillOptions> options = [];

    // Handle multi-type matching (check all categories)
    if (type == 'multi') {
      // Try URLs first
      final urlMatches = FuzzySearch.searchList(urls, query);
      for (var match in urlMatches) {
        options.add(
          FillOptions(
            type: 'url',
            ranges: [
              [start, end],
            ],
            label: match.text,
            value: match.text,
            fuzzyMatch: match,
          ),
        );
      }

      // Try variables
      final variableMatches = FuzzySearch.searchList(variables, query);
      for (var match in variableMatches) {
        options.add(
          FillOptions(
            type: 'variable',
            ranges: [
              [start, end],
            ],
            label: match.text,
            value: '{{${match.text}}}',
            fuzzyMatch: match,
          ),
        );
      }

      // Try functions
      final functionMatches = FuzzySearch.searchList(functions, query);
      for (var match in functionMatches) {
        options.add(
          FillOptions(
            type: 'function',
            ranges: [
              [start, end],
            ],
            label: '${match.text}()',
            value: '{{${match.text}()}}',
            fuzzyMatch: match,
          ),
        );
      }

      // Sort all options by fuzzy match score
      options.sort((a, b) {
        final aScore = a.fuzzyMatch?.score ?? 0;
        final bScore = b.fuzzyMatch?.score ?? 0;
        return bScore.compareTo(aScore);
      });

      return options;
    }

    // Handle specific type matching
    if (type == 'url') {
      final matches = FuzzySearch.searchList(urls, query);
      for (var match in matches) {
        // Don't show suggestion if it matches exactly what user typed
        if (match.text == query) {
          continue;
        }

        options.add(
          FillOptions(
            type: 'url',
            ranges: [
              [start, end],
            ],
            label: match.text,
            value: match.text,
            fuzzyMatch: match,
          ),
        );
      }
    } else if (type == 'variable') {
      final matches = FuzzySearch.searchList(variables, query);
      for (var match in matches) {
        // Since detectTypingContext returns the range starting at {{ for variables,
        // we MUST include the braces in the replacement value, otherwise they get stripped.
        // E.g., replacing '{{base' with 'baseUrl' results in 'test/baseUrl' instead of 'test/{{baseUrl}}'.
        final wrappedValue = '{{${match.text}}}';

        options.add(
          FillOptions(
            type: 'variable',
            ranges: [
              [start, end],
            ],
            label: match.text,
            value: wrappedValue,
            fuzzyMatch: match,
          ),
        );
      }
    } else if (type == 'function') {
      final matches = FuzzySearch.searchList(functions, query);
      for (var match in matches) {
        final wrappedValue = '{{${match.text}()}}';

        options.add(
          FillOptions(
            type: 'function',
            ranges: [
              [start, end],
            ],
            label: '${match.text}()',
            value: wrappedValue,
            fuzzyMatch: match,
          ),
        );
      }
    }

    return options;
  }

  static (String, int) onOptionPick(String text, FillOptions option) {
    final range = option.ranges.first;
    final start = range[0];
    final end = range[1];

    // Replace text at the specific range
    final newText =
        text.substring(0, start) + option.value + text.substring(end);

    final newCursorPos = start + option.value.length;
    return (newText, newCursorPos);
  }
}
