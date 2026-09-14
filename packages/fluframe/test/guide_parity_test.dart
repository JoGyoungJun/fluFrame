// The auth guides claim byte-parity with the addon sources. This gate
// makes that claim testable.
//
// `docs/guides/auth-firebase.md` and `auth-supabase.md` both say "Every
// step below produces the same code `--backend <backend>` generates", and
// name the addon file as the source of truth. They have drifted from it
// twice: once recorded in CHANGELOG 1.5.0, and again when 1.9.0 changed
// the unconfigured fallback from `InMemoryAuthRepository` to
// `unconfiguredBackendRepository` and the guides kept publishing the old
// line.
//
// That second drift is why this is a gate rather than a review note. The
// in-memory fake signs in any email with a six-character password. A
// reader adding a backend to an already-generated app follows the guide,
// writes the old line, and re-opens in their release build exactly the
// hole 1.9.0 shipped a minor to close — in the file the guide names as
// authoritative.

import 'dart:io';

import 'package:test/test.dart';

/// The guide, and the addon file whose contents its `dart` block must
/// reproduce exactly.
const _pairs = <String, String>{
  '../../docs/guides/auth-firebase.md':
      '../../template_addons/firebase/lib/features/auth/data/'
      'firebase_auth_repository.dart',
  '../../docs/guides/auth-supabase.md':
      '../../template_addons/supabase/lib/features/auth/data/'
      'supabase_auth_repository.dart',
};

String _read(String path) {
  expect(
    File(path).existsSync(),
    isTrue,
    reason:
        'run from packages/fluframe: "$path" must resolve, because this '
        'gate compares the real guide against the real addon source and '
        'has nothing to check without both',
  );
  return File(path).readAsStringSync().replaceAll('\r\n', '\n');
}

void main() {
  group('auth guides reproduce their addon source verbatim', () {
    _pairs.forEach((guidePath, sourcePath) {
      final guideName = guidePath.split('/').last;

      test('$guideName embeds the addon repository file unchanged', () {
        final guide = _read(guidePath);
        final source = _read(sourcePath);

        expect(
          source,
          contains('unconfiguredBackendRepository('),
          reason:
              'the addon source must still route the unconfigured case '
              'through the fail-closed helper, or this gate is comparing '
              'against the wrong thing',
        );

        final fenced = '```dart\n${source.trimRight()}\n```';
        expect(
          guide,
          contains(fenced),
          reason:
              '$guideName must embed $sourcePath verbatim inside a ```dart '
              'block. It claims byte-parity with that file, so a reader '
              'who follows it gets whatever this block says. Re-copy the '
              'file into the guide rather than editing the block by hand.',
        );
      });

      test('$guideName never hands the unconfigured case to the fake', () {
        final guide = _read(guidePath);

        // The fake is still named in the guide's opening sentence and in a
        // `diff` block that REMOVES the old call, both correct. What must
        // not appear is a surviving line that routes the unconfigured
        // fallback to it — the 1.9.0 regression, in the exact shape it took.
        final offenders = guide
            .split('\n')
            .map((l) => l.trimRight())
            .where((l) => l.contains('InMemoryAuthRepository(store)'))
            .where((l) => !l.startsWith('-')) // a diff removal is fine
            .toList();

        expect(
          offenders,
          isEmpty,
          reason:
              'InMemoryAuthRepository signs in any email with a '
              'six-character password. A guide line that falls back to it '
              'puts that in a release build. Route the unconfigured case '
              'through unconfiguredBackendRepository instead. Offending '
              'lines: $offenders',
        );
      });
    });
  });
}
