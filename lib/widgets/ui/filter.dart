import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

// final List<String> variables = [
//   'baseUrl',
//   'apiKey',
//   'userId',
//   'userName',
//   'token',
// ];
// final List<String> urls = [
//   'https://api.example.com',
//   'https://google.com',
//   'http://localhost:3000',
//   'https://test/{{token}}',
//   'https://test/{{token}}/magictext',
// ];
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
  final List<String> variables;
  final List<String> urls;

  FilterService({required this.variables, required this.urls});

  static bool _isWordBoundary(String char) {
    return char == ' ' ||
        char == '\n' ||
        char == '\t' ||
        char == ',' ||
        char == ';' ||
        char == '/';
  }

  static bool _isAlpha(String char) {
    if (char.isEmpty) return false;
    final code = char.codeUnitAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }

  static Map<String, dynamic> detectTypingContext(TextEditingValue value) {
    final text = value.text;
    final cursorPos = value.selection.baseOffset;

    if (cursorPos <= 0 || text.isEmpty) {
      return {'type': 'none', 'query': '', 'start': 0, 'end': 0};
    }

    // Check if cursor is inside {{ }}
    int braceStart = -1;
    int braceEnd = -1;

    for (int i = cursorPos - 1; i >= 1; i--) {
      if (text[i] == '}' && text[i - 1] == '}') break;
      if (text[i - 1] == '{' && text[i] == '{') {
        braceStart = i - 1;
        break;
      }
    }

    for (int i = cursorPos; i < text.length - 1; i++) {
      if (text[i] == '}' && text[i + 1] == '}') {
        braceEnd = i + 2;
        break;
      }
    }

    // Inside braces logic
    if (braceStart != -1 && (braceEnd == -1 || braceEnd > cursorPos)) {
      final contentStart = braceStart + 2;
      final contentEnd = braceEnd != -1 ? braceEnd - 2 : cursorPos;
      final content = text.substring(contentStart, contentEnd);

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

    // Partial braces logic
    if (cursorPos >= 2 && text.substring(cursorPos - 2, cursorPos) == '{{') {
      return {
        'type': 'variable',
        'query': '',
        'start': cursorPos - 2,
        'end': cursorPos,
        'insideBraces': true,
      };
    }

    // Standard word logic
    int wordStart = cursorPos;
    while (wordStart > 0 && !_isWordBoundary(text[wordStart - 1])) {
      wordStart--;
    }

    int wordEnd = cursorPos;
    while (wordEnd < text.length && !_isWordBoundary(text[wordEnd])) {
      wordEnd++;
    }

    // Smart URL expansion (looks for http:// etc)
    if (wordStart > 0 && text[wordStart - 1] == '/') {
      int expansionStart = wordStart;
      while (expansionStart > 0 &&
          (text[expansionStart - 1] == '/' ||
              text[expansionStart - 1] == ':')) {
        expansionStart--;
      }
      if (expansionStart < wordStart) {
        int protocolStart = expansionStart;
        while (protocolStart > 0 && _isAlpha(text[protocolStart - 1])) {
          protocolStart--;
        }
        final potentialProtocol = text.substring(protocolStart, expansionStart);
        if (potentialProtocol == 'http' || potentialProtocol == 'https') {
          wordStart = protocolStart;
        }
      }
    }

    final word = text.substring(wordStart, wordEnd);

    if (word.isEmpty) {
      return {'type': 'none', 'query': '', 'start': 0, 'end': 0};
    }

    // If word looks like URL
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

    return {
      'type': 'multi',
      'query': word,
      'start': wordStart,
      'end': wordEnd,
      'insideBraces': false,
    };
  }

  List<FillOptions> getOptions(
    TextEditingValue value, {

    bool enableUrlSuggestions = false,
  }) {
    final context = detectTypingContext(value);
    final String type = context['type'];
    final String query = context['query'];
    final int start = context['start'];
    final int end = context['end'];

    if (type == 'none') {
      return [];
    }

    List<FillOptions> options = [];

    // Helper to add URL options
    // 2. We use [0, text.length] as the range to trigger "Replace All" behavior
    void addUrlOptions() {
      if (!enableUrlSuggestions) return; // Check global toggle
      debugPrint("url suggestion enabled, searching URLs for query: $query");
      final urlMatches = FuzzySearch.searchList(urls, value.text);
      for (var match in urlMatches) {
        // Optional: Skip exact match if you don't want to suggest what is already typed
        if (match.text == query) continue;

        options.add(
          FillOptions(
            type: 'url',
            ranges: [
              // CRITICAL FIX: Replace the WHOLE string, not just the token
              [0, value.text.length],
            ],
            label: match.text,
            value: match.text,
            fuzzyMatch: match,
          ),
        );
      }
    }

    // Helper to add Variable options
    void addVariableOptions() {
      final variableMatches = FuzzySearch.searchList(variables, query);
      for (var match in variableMatches) {
        options.add(
          FillOptions(
            type: 'variable',
            ranges: [
              [start, end], // Variables still replace only the current word
            ],
            label: match.text,
            value: '{{${match.text}}}',
            fuzzyMatch: match,
          ),
        );
      }
    }

    // Helper to add Function options
    void addFunctionOptions() {
      final functionMatches = FuzzySearch.searchList(functions, query);
      for (var match in functionMatches) {
        options.add(
          FillOptions(
            type: 'function',
            ranges: [
              [start, end], // Functions still replace only the current word
            ],
            label: '${match.text}()',
            value: '{{${match.text}()}}',
            fuzzyMatch: match,
          ),
        );
      }
    }

    if (type == 'multi') {
      addUrlOptions();
      addVariableOptions();
      addFunctionOptions();

      // Sort combined results by score
      options.sort((a, b) {
        final aScore = a.fuzzyMatch?.score ?? 0;
        final bScore = b.fuzzyMatch?.score ?? 0;
        return bScore.compareTo(aScore);
      });
    } else if (type == 'url') {
      addUrlOptions();
    } else if (type == 'variable') {
      addVariableOptions();
    } else if (type == 'function') {
      addFunctionOptions();
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
