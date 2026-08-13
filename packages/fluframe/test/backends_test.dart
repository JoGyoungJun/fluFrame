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
