import 'package:fluframe/src/sdk_constraint.dart';
import 'package:test/test.dart';

void main() {
  group('parseSemVer', () {
    test('reads the version out of a real dart banner', () {
      final version = parseSemVer(
        'Dart SDK version: 3.12.1 (stable) on "windows_x64"',
      );

      expect(version, (major: 3, minor: 12, patch: 1));
    });

    test('reads the version out of a real flutter banner', () {
      final version = parseSemVer(
        'Flutter 3.44.0 • channel stable • https://github.com/flutter',
      );

      expect(version, (major: 3, minor: 44, patch: 0));
    });

    test('returns null when there is no version at all', () {
      expect(parseSemVer('command not found'), isNull);
    });
  });

  group('dartConstraintFrom', () {
    test('reads environment.sdk', () {
      const pubspec = '''
name: fluframe_app

environment:
  sdk: ^3.12.1

dependencies:
  flutter:
    sdk: flutter
''';

      expect(dartConstraintFrom(pubspec), '^3.12.1');
    });

    test('does not mistake a dependency sdk: flutter for the constraint', () {
      // Regression guard for the hand-rolled parser: `sdk: flutter` appears
      // twice under dependencies in every generated app.
      const pubspec = '''
name: fluframe_app

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
''';

      expect(dartConstraintFrom(pubspec), isNull);
    });

    test('tolerates quoting', () {
      const pubspec = "environment:\n  sdk: '>=3.0.0 <4.0.0'\n";

      expect(dartConstraintFrom(pubspec), '>=3.0.0 <4.0.0');
    });
  });

  group('checkDartVersion', () {
    test('accepts a version inside the caret range', () {
      expect(checkDartVersion('3.12.1', '^3.12.1'), SdkVerdict.ok);
      expect(checkDartVersion('3.99.0', '^3.12.1'), SdkVerdict.ok);
    });

    test('rejects a version below the floor', () {
      expect(checkDartVersion('3.12.0', '^3.12.1'), SdkVerdict.tooOld);
      expect(checkDartVersion('3.11.9', '^3.12.1'), SdkVerdict.tooOld);
      expect(checkDartVersion('1.0.0', '^3.12.1'), SdkVerdict.tooOld);
    });

    test('rejects a version at or past the next major', () {
      expect(checkDartVersion('4.0.0', '^3.12.1'), SdkVerdict.tooNew);
      expect(checkDartVersion('5.1.2', '^3.12.1'), SdkVerdict.tooNew);
    });

    test('handles an explicit range', () {
      expect(checkDartVersion('3.5.0', '>=3.0.0 <4.0.0'), SdkVerdict.ok);
      expect(checkDartVersion('2.9.0', '>=3.0.0 <4.0.0'), SdkVerdict.tooOld);
      expect(checkDartVersion('4.0.0', '>=3.0.0 <4.0.0'), SdkVerdict.tooNew);
    });

    test('claims nothing it cannot determine', () {
      // A wrong floor rejects a machine that would have worked, so an
      // unreadable version or constraint must not be reported as a failure.
      const unknown = SdkVerdict.unknown;

      expect(checkDartVersion('3.12.1', null), unknown);
      expect(checkDartVersion('no version here', '^3.12.1'), unknown);
      expect(checkDartVersion('3.12.1', 'any'), unknown);
    });
  });

  group('boundsOf', () {
    test('caret below 1.0.0 bounds by the next minor', () {
      final bounds = boundsOf('^0.4.2');

      expect(bounds?.min, (major: 0, minor: 4, patch: 2));
      expect(bounds?.max, (major: 0, minor: 5, patch: 0));
    });

    test('an open-ended range has no ceiling', () {
      expect(boundsOf('>=3.0.0')?.max, isNull);
    });
  });
}
