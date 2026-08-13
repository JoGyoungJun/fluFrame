import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Message keys (everything except `@`-prefixed metadata) in an ARB file.
Set<String> _messageKeys(File arb) {
  final decoded = jsonDecode(arb.readAsStringSync()) as Map<String, Object?>;
  return {
    for (final key in decoded.keys)
      if (!key.startsWith('@')) key,
  };
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
    }
  });
}
