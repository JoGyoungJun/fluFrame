import 'dart:convert';

import 'package:fluframe/src/backends.dart';
import 'package:test/test.dart';

void main() {
  group('addon registry', () {
    test('round-trips every shipped addon through JSON', () {
      // The registry travels inside a published bundle so a FUTURE CLI can
      // rebuild an OLD merge base with the anchors of its own era. If any
      // field is dropped here, that reconstruction silently diverges.
      final decoded = decodeAddonRegistry(
        jsonDecode(jsonEncode(encodeAddonRegistry())) as Map<String, Object?>,
      );

      expect(decoded.backends.keys, unorderedEquals(backendAddons.keys));
      expect(
        decoded.errorReporting.keys,
        unorderedEquals(errorReportingAddons.keys),
      );
      expect(decoded.analytics.keys, unorderedEquals(analyticsAddons.keys));

      for (final entry in backendAddons.entries) {
        final original = entry.value;
        final restored = decoded.backends[entry.key]!;
        expect(restored.name, original.name);
        expect(restored.dependencies, original.dependencies);
        expect(restored.requiresFiles, original.requiresFiles);
        expect(restored.postCreateNotes, original.postCreateNotes);
        expect(restored.patches, hasLength(original.patches.length));
        for (var i = 0; i < original.patches.length; i++) {
          expect(restored.patches[i].file, original.patches[i].file);
          expect(restored.patches[i].anchor, original.patches[i].anchor);
          expect(
            restored.patches[i].replacement,
            original.patches[i].replacement,
          );
        }
      }
    });

    test('rejects a schema it does not understand', () {
      // A newer bundle read by an older CLI must fall back, not guess.
      expect(
        () => decodeAddonRegistry({'schema': 99}),
        throwsA(isA<FormatException>()),
      );
    });

    test('a malformed patch names the offending key', () {
      // #187, third recurrence. A registry is read out of a DOWNLOADED
      // bundle, and each of these met a bare `as` or `!` and threw a
      // TypeError — an Error, not the FormatException `fluframe upgrade`
      // catches to fall back to this CLI's own definitions. The
      // documented fallback was unreachable for the whole class.
      const broken = <(String, Map<String, Object?>)>[
        ('file', {'anchor': 'a', 'replacement': 'b'}),
        ('anchor', {'file': 'lib/main.dart', 'replacement': 'b'}),
        ('anchor', {'file': 'lib/main.dart', 'anchor': 5, 'replacement': 'b'}),
        ('replacement', {'file': 'lib/main.dart', 'anchor': 'a'}),
      ];

      for (final (key, json) in broken) {
        expect(
          () => AddonPatch.fromJson(json),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains(key),
            ),
          ),
          reason: 'did not name "$key" in $json',
        );
      }
    });

    test('a malformed addon names the offending key', () {
      const broken = <(String, Map<String, Object?>)>[
        ('name', {'dependencies': [], 'patches': []}),
        ('name', {'name': 5, 'dependencies': [], 'patches': []}),
        ('dependencies', {'name': 'x', 'patches': []}),
        ('dependencies', {'name': 'x', 'dependencies': [1], 'patches': []}),
        ('patches', {'name': 'x', 'dependencies': []}),
        ('patches', {'name': 'x', 'dependencies': [], 'patches': 'nope'}),
        ('patches', {'name': 'x', 'dependencies': [], 'patches': [5]}),
      ];

      for (final (key, json) in broken) {
        expect(
          () => BackendAddon.fromJson(json),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains(key),
            ),
          ),
          reason: 'did not name "$key" in $json',
        );
      }
    });

    test('a wrong-typed optional field is data, not a crash', () {
      // `as bool?` / `as List<dynamic>?` is null-safe only for a MISSING
      // key: present-but-wrong reached the cast and threw all the same.
      for (final key in ['requiresFiles', 'postCreateNotes']) {
        expect(
          () => BackendAddon.fromJson({
            'name': 'x',
            'dependencies': [],
            'patches': [],
            key: 'wrong',
          }),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains(key),
            ),
          ),
          reason: 'did not name "$key"',
        );
      }
    });

    test('an addon section holding a non-object names the addon', () {
      expect(
        () => decodeAddonRegistry({'schema': 1, 'backends': {'legacy': 5}}),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('legacy'),
          ),
        ),
      );
    });

    test('every dependency carries a version constraint', () {
      // Unconstrained `pub add` resolves to whatever is latest at
      // generation time, while the injected sources target one major —
      // so the next upstream major breaks new apps on its release day.
      for (final addon in [
        ...backendAddons.values,
        ...errorReportingAddons.values,
        ...analyticsAddons.values,
      ]) {
        for (final dependency in addon.dependencies) {
          expect(
            dependency,
            contains(':'),
            reason: '${addon.name} depends on "$dependency" unconstrained',
          );
        }
      }
    });
  });
}
