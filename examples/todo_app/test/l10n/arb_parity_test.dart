import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Messages (everything except `@`-prefixed metadata) in an ARB file.
Map<String, String> _messages(File arb) {
  final decoded = jsonDecode(arb.readAsStringSync()) as Map<String, Object?>;
  return {
    for (final entry in decoded.entries)
      if (!entry.key.startsWith('@') && entry.value is String)
        entry.key: entry.value! as String,
  };
}

/// Message keys (everything except `@`-prefixed metadata) in an ARB file.
Set<String> _messageKeys(File arb) => _messages(arb).keys.toSet();

/// Placeholder names an ARB message value references.
///
/// A reference is a `{` whose name is followed only by `}` (`{email}`) or
/// by `,` (`{count, plural, ...}`) — including the ones nested inside
/// plural and select ARMS, which is exactly where a key-set comparison is
/// blind. An arm opener (`other{`, `=1{`) is an arm name glued to `{`, so
/// the character in front of the brace is what tells the two apart:
/// `other{Retry}` is an arm, `Post #{id}` is a reference.
///
/// Known limitation: a placeholder glued straight onto a word — `Post{id}`
/// with no separator — reads as an arm opener and is skipped. That makes
/// the check miss something, never invent it, and no message in this
/// template is written that way.
Set<String> _placeholders(String message) {
  final result = <String>{};
  for (final match in RegExp(
    r'(.?)\{\s*(\w+)\s*(?=[,}])',
  ).allMatches(message)) {
    final before = match.group(1) ?? '';
    if (before.isNotEmpty && RegExp(r'[\w=]').hasMatch(before)) continue;
    result.add(match.group(2)!);
  }
  return result;
}

void main() {
  // `flutter gen-l10n` falls back to English for a missing key and only
  // warns, so analyze and test both stay green while a locale silently
  // stops being translated. Nothing else in CI compares the ARBs, which
  // is how the app shipped a Japanese chip label with no Japanese string
  // behind it. This is that check.
  group('ARB locale parity', () {
    final directory = Directory('lib/l10n');
    final english = File('${directory.path}/app_en.arb');

    test('app_en.arb is the reference and exists', () {
      expect(english.existsSync(), isTrue, reason: english.path);
    });

    final translations = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.arb'))
        .where((file) => !file.path.endsWith('app_en.arb'))
        .toList();

    test('there is at least one translation to check', () {
      expect(translations, isNotEmpty, reason: directory.path);
    });

    for (final translation in translations) {
      final name = translation.uri.pathSegments.last;

      test('$name has exactly the keys app_en.arb has', () {
        final expected = _messageKeys(english);
        final actual = _messageKeys(translation);

        expect(
          expected.difference(actual),
          isEmpty,
          reason: 'missing from $name — these fall back to English silently',
        );
        expect(
          actual.difference(expected),
          isEmpty,
          reason: 'in $name but not app_en.arb — a stale or misspelled key',
        );
      });

      // Same key, same string — different interpolations. `gen-l10n`
      // generates one method signature from the ENGLISH ARB, so a
      // translation that drops `{email}` compiles, passes the key check
      // above, and renders a sentence with the value missing; one that
      // invents `{name}` renders the brace text literally. Neither is
      // visible until somebody runs the app in that locale.
      test('$name uses exactly the placeholders app_en.arb uses', () {
        final expected = _messages(english);
        final actual = _messages(translation);

        for (final entry in expected.entries) {
          final translated = actual[entry.key];
          // A key missing from the translation is the check above's to
          // report; failing here too would only double the noise.
          if (translated == null) continue;
          expect(
            _placeholders(translated),
            _placeholders(entry.value),
            reason:
                '$name -> ${entry.key}\n'
                '    en: ${entry.value}\n'
                '    $name: $translated',
          );
        }
      });
    }
  });
}
