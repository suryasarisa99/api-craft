import 'package:api_craft/widgets/ui/filter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// import 'package:test/test.dart';

void main() {
  /// =============== Check Suggestions Tests ===============

  /// variable tests
  checkSuggestionsTest('base', 'baseUrl');
  checkSuggestionsTest('test/{{base', 'baseUrl');
  checkSuggestionsTest('test/base', 'baseUrl');

  /// url tests
  checkSuggestionsTest('https:', 'https://google.com');
  // for urls exact matches,don't suggest.
  checkSuggestionsTest('https://google.com', null);
  checkSuggestionsTest('google', 'https://google.com');

  // function tests
  checkSuggestionsTest('getDa', 'getData()');
  checkSuggestionsTest('post', 'postData()');

  /// =============== Pick Suggestions Tests ===============

  /// variable
  pickSuggestionTest('base', '{{baseUrl}}');
  pickSuggestionTest('test/{{base', 'test/{{baseUrl}}');
  pickSuggestionTest('test/base', 'test/{{baseUrl}}');
  pickSuggestionTest('test/baseUrl', 'test/{{baseUrl}}');
  pickSuggestionTest(
    'test/{{baseUrl}}/baseUrl',
    'test/{{baseUrl}}/{{baseUrl}}',
  );
  pickSuggestionTest(
    'test/{{baseUrl}}/{{baseU',
    'test/{{baseUrl}}/{{baseUrl}}',
  );
  pickSuggestionTest(
    'test/{{baseUrl}}/{{baseUrl}}/{{userId}}/userNa',
    'test/{{baseUrl}}/{{baseUrl}}/{{userId}}/{{userName}}',
  );
  // already complete,so no suggestion should be shown
  pickSuggestionTest('test/{{baseUrl}}', null);
  pickSuggestionTest('{{baseUrl}}', null);

  /// url
  pickSuggestionTest('https://api.', 'https://api.example.com');
  pickSuggestionTest('google', 'https://google.com');

  /// function
  pickSuggestionTest('getDa', '{{getData()}}');
  pickSuggestionTest('post', '{{postData()}}');
  pickSuggestionTest(
    '{{baseUrl}}/{{baseUrl}}/post',
    '{{baseUrl}}/{{baseUrl}}/{{postData()}}',
  );

  /// =============== Cursor Position Tests ===============
  pickSuggestionTest('test/base/post', 'test/{{baseUrl}}/post', 9);
}

void checkSuggestionsTest(String text, String? expected, [int? cursorPos]) {
  test('checking suggestions for :: $text', () {
    final cursorPosition = cursorPos ?? text.length;
    final textEditingValue = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursorPosition),
    );
    final suggestions = FilterService.getOptions(textEditingValue);
    final labels = suggestions.map((e) => e.label).toList();
    if (expected == null) {
      expect(labels, [], reason: 'reason: labels: $labels');
      return;
    }
    expect(labels, contains(expected), reason: 'reason: labels: $labels');
  });
}

void pickSuggestionTest(String text, String? value, [int? cursorPos]) {
  test('picking suggestion for :: $text', () {
    final cursorPosition = cursorPos ?? text.length;
    final textEditingValue = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursorPosition),
    );
    final suggestions = FilterService.getOptions(textEditingValue);
    if (value == null) {
      expect(suggestions, [], reason: 'reason: no suggestions should be found');
      return;
    }
    final firstOption = suggestions.first;
    final result = FilterService.onOptionPick(
      textEditingValue.text,
      firstOption,
    );
    expect(result.$1, value, reason: 'reason: ${result.$1}');
  });
}
