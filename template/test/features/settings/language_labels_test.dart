import 'package:fluframe_app/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A language picker names languages by their endonym, so a reader
  // looking for Japanese recognizes 日本語 whatever the UI language is.
  // app_en.arb used to say "Japanese" while ko and ja both said 日本語,
  // which made the English picker read: System English 한국어 Japanese.
  //
  // Asserted against the literal rather than "all three agree", because
  // all three agreeing on "Japanese" would satisfy that and be the bug.
  group('language chip labels are endonyms in every locale', () {
    const cases = {
      'ko': '한국어',
      'ja': '日本語',
    };

    for (final locale in AppLocalizations.supportedLocales) {
      final code = locale.languageCode;

      test('$code names each language by its own endonym', () {
        final l10n = lookupAppLocalizations(Locale(code));

        expect(l10n.languageKorean, cases['ko'], reason: code);
        expect(l10n.languageJapanese, cases['ja'], reason: code);
      });
    }
  });
}
