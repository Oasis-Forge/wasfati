// LANG-2, LANG-3: every message exists in every language with the same
// placeholders, none is left in English in the Arabic file, no number is
// baked into a message's text (it comes in as a placeholder, in the user's
// digits), and no screen writes its own user-facing words.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/l10n/app_localizations.dart';

Map<String, dynamic> _arb(String language) =>
    jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync())
        as Map<String, dynamic>;

Map<String, String> _messages(Map<String, dynamic> arb) => {
  for (final MapEntry(:key, :value) in arb.entries)
    if (!key.startsWith('@')) key: value as String,
};

/// The placeholders [text] uses: `{name}` or `{name, plural, ...}`, but not
/// a plural case's own braces (`=1{...}`, `other{...}`).
Set<String> _used(String text) => {
  for (final m in RegExp(r'(?<![=\w])\{\s*(\w+)\s*[},]').allMatches(text))
    m[1]!,
};

/// [text] without its placeholders and ICU keywords: the words a reader
/// sees whatever the numbers are. A select's case keys (`sat{...}`) are
/// keywords too, never shown.
String _words(String text) => text
    .replaceAll(RegExp(r'\{\s*\w+\s*,\s*(plural|select)\s*,'), '{')
    .replaceAll(RegExp(r'(=\d+|zero|one|two|few|many|other)\{'), '{')
    .replaceAll(RegExp(r'\b[a-z]\w*\{'), '{')
    .replaceAll(RegExp(r'\{\s*\w+\s*\}'), '');

/// Brand names that stay in Latin letters inside Arabic text.
const _brands = {'Google', 'Play'};

/// Demo lines the walkthrough parses and shows through the amount
/// formatter, which puts them in the user's digits (RUN-4, QTY-5): their
/// numbers are content, not the app's own words.
const _demoLines = {
  'walkthroughDemoLine1',
  'walkthroughDemoLine2',
  'walkthroughDemoLine3',
  'walkthroughDemoStep',
};

void main() {
  final en = _arb('en');
  final ar = _arb('ar');
  final enMessages = _messages(en);
  final arMessages = _messages(ar);

  test('LANG-2: both languages have exactly the same messages', () {
    expect(arMessages.keys.toSet(), enMessages.keys.toSet());
  });

  test('LANG-2: each message uses the same placeholders in both languages, '
      'and only declared ones', () {
    final problems = <String>[];
    for (final key in enMessages.keys) {
      final declared =
          ((en['@$key'] as Map?)?['placeholders'] as Map?)?.keys
              .cast<String>()
              .toSet() ??
          <String>{};
      for (final (language, text) in [
        ('en', enMessages[key]!),
        ('ar', arMessages[key]!),
      ]) {
        final used = _used(text);
        if (!used.containsAll(declared) || !declared.containsAll(used)) {
          problems.add('$key ($language): uses $used, declares $declared');
        }
      }
    }
    expect(problems, isEmpty);
  });

  test('LANG-2: nothing in the Arabic file is left in English', () {
    final problems = <String>[];
    for (final MapEntry(:key, value: text) in arMessages.entries) {
      final words = _words(text);
      final latin = RegExp(r'[A-Za-z]{2,}')
          .allMatches(words)
          .map((m) => m[0]!)
          .where((w) => !_brands.contains(w));
      if (latin.isNotEmpty) problems.add('$key: ${latin.join(', ')}');
      final hasLetters = RegExp(r'[A-Za-z؀-ۿ]').hasMatch(words);
      final arabic = RegExp(r'[؀-ۿ]').hasMatch(words);
      if (hasLetters && !arabic) problems.add('$key: no Arabic');
    }
    expect(problems, isEmpty);
  });

  test('LANG-3: no number is baked into a message; it comes in as a '
      'placeholder, in the user\'s digits', () {
    final problems = <String>[
      for (final (language, messages) in [
        ('en', enMessages),
        ('ar', arMessages),
      ])
        for (final MapEntry(:key, value: text) in messages.entries)
          if (!_demoLines.contains(key) &&
              RegExp(r'[0-9٠-٩]').hasMatch(_words(text)))
            '$key ($language): ${_words(text)}',
    ];
    expect(problems, isEmpty);
  });

  test('LANG-3: English\'s "one" case shows the number it is given, so '
      'Arabic digits read "١ serving"', () {
    final l = lookupAppLocalizations(const Locale('en'));
    expect(l.servings(1, '١'), '١ serving');
    expect(l.recipesCount(1, '١'), '١ recipe');
    expect(l.minutes(1, '١'), '١ min');
  });

  test('LANG-2: the AI-import line\'s noun agrees with the quota, the free '
      '10 and Premium\'s 100 alike (QTY-6)', () {
    const month = ' هذا الشهر · تتجدد في الأول من كل شهر';
    final ar = lookupAppLocalizations(const Locale('ar'));
    expect(
      ar.aiImportsLeftLine(10, '7', '10'),
      'بقي 7 من 10 استيرادات ذكية$month',
    );
    expect(
      ar.aiImportsLeftLine(100, '88', '100'),
      'بقي 88 من 100 استيراد ذكي$month',
    );
    expect(
      ar.aiImportsLeftLine(11, '5', '11'),
      'بقي 5 من 11 استيرادًا ذكيًا$month',
    );
    expect(
      ar.aiImportsLeftLine(100, '٨٨', '١٠٠'),
      'بقي ٨٨ من ١٠٠ استيراد ذكي$month',
    );
    final en = lookupAppLocalizations(const Locale('en'));
    expect(
      en.aiImportsLeftLine(100, '88', '100'),
      '88 of 100 AI imports left this month · resets at the start of each '
      'month',
    );
  });

  test('LANG-2: no screen or widget writes its own user-facing words', () {
    // A string literal with a letter in it, as a Text's text or as a
    // tooltip, label, hint, title, message or semantics label.
    final literal = RegExp(
      r'''(Text\(\s*|(tooltip|[lL]abel|labelText|hintText|helperText|errorText|title|message|semanticsLabel|semanticLabel)\s*:\s*(const\s+)?)'[^'$]*[A-Za-z؀-ۿ][^']*'|'''
      r'''(Text\(\s*|(tooltip|[lL]abel|labelText|hintText|helperText|errorText|title|message|semanticsLabel|semanticLabel)\s*:\s*(const\s+)?)"[^"$]*[A-Za-z؀-ۿ][^"]*"''',
    );
    final files = [
      File('lib/app.dart'),
      for (final dir in ['lib/screens', 'lib/widgets'])
        ...Directory(dir)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart')),
    ];
    final problems = <String>[];
    for (final file in files) {
      final lines = const LineSplitter().convert(file.readAsStringSync());
      for (final (i, line) in lines.indexed) {
        if (line.trimLeft().startsWith('//')) continue;
        final m = literal.firstMatch(line);
        if (m != null) problems.add('${file.path}:${i + 1}: ${m[0]}');
      }
    }
    expect(problems, isEmpty);
  });
}
