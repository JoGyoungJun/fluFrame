import 'dart:io';

import 'package:fluframe/src/backends.dart';
import 'package:fluframe/src/package_name.dart';
import 'package:test/test.dart';

void main() {
  group('isValidPackageName', () {
    test('accepts lower_snake_case names', () {
      expect(isValidPackageName('my_app'), isTrue);
      expect(isValidPackageName('app2'), isTrue);
      expect(isValidPackageName('demo_app'), isTrue);
    });

    test('rejects invalid names', () {
      expect(isValidPackageName('MyApp'), isFalse);
      expect(isValidPackageName('1app'), isFalse);
      expect(isValidPackageName('my-app'), isFalse);
      expect(isValidPackageName('my app'), isFalse);
      expect(isValidPackageName(''), isFalse);
      // pub tolerates a leading underscore; flutter create and every
      // import in the generated app do not benefit from it.
      expect(isValidPackageName('_private'), isFalse);
    });

    test('rejects Dart reserved words', () {
      expect(isValidPackageName('class'), isFalse);
      expect(isValidPackageName('switch'), isFalse);
      expect(isValidPackageName('void'), isFalse);
    });

    test('rejects names the generated app already depends on', () {
      // Each of these used to pass validation and then fail generation
      // with "A package may not list itself as a dependency".
      for (final name in ['dio', 'go_router', 'intl', 'shared_preferences']) {
        expect(isValidPackageName(name), isFalse, reason: name);
      }
      // Addon dependencies count too — `--backend firebase` pub-adds them.
      expect(isValidPackageName('firebase_core'), isFalse);
      expect(isValidPackageName('sentry_flutter'), isFalse);
    });

    test('rejects Windows reserved device names', () {
      // `flutter create con` fails with a raw OS error (errno 161) after
      // a minute of work, on Windows only.
      for (final name in ['con', 'aux', 'nul', 'com1', 'lpt9']) {
        expect(isValidPackageName(name), isFalse, reason: name);
      }
    });
  });

  group('packageNameRejection', () {
    test('returns null for a usable name', () {
      expect(packageNameRejection('my_app'), isNull);
    });

    test('names the actual reason, not a generic syntax rule', () {
      expect(packageNameRejection('dio'), contains('depends on a package'));
      expect(packageNameRejection('con'), contains('reserved device name'));
      expect(packageNameRejection('class'), contains('reserved word'));
      expect(packageNameRejection('MyApp'), contains('lower_snake_case'));
    });
  });

  group('generatedAppDependencyNames', () {
    // A new dependency that is not listed here reopens the hole: the CLI
    // would accept its name and generation would fail after writing the
    // whole project.
    test('covers every dependency in template/pubspec.yaml', () {
      final pubspec = File(
        '../../template/pubspec.yaml',
      ).readAsStringSync().replaceAll('\r\n', '\n');
      final entry = RegExp('^  ([a-z_][a-z0-9_]*):');
      final declared = <String>{};
      var inDependencies = false;
      for (final line in pubspec.split('\n')) {
        if (RegExp('^(dev_)?dependencies:').hasMatch(line)) {
          inDependencies = true;
          continue;
        }
        if (line.isNotEmpty && !line.startsWith(' ')) {
          inDependencies = false;
          continue;
        }
        if (!inDependencies) continue;
        final match = entry.firstMatch(line);
        if (match != null) declared.add(match.group(1)!);
      }

      expect(declared, contains('dio'), reason: 'template pubspec must parse');
      expect(
        declared.difference(generatedAppDependencyNames),
        isEmpty,
        reason:
            'Add these to generatedAppDependencyNames in '
            'lib/src/package_name.dart.',
      );
    });

    test('covers every addon dependency', () {
      final addonDependencies = {
        for (final addon in [
          ...backendAddons.values,
          ...errorReportingAddons.values,
          ...analyticsAddons.values,
        ])
          ...addon.dependencies,
      }.map((dependency) => dependency.split(':').first).toSet();

      expect(addonDependencies, isNotEmpty);
      expect(
        addonDependencies.difference(generatedAppDependencyNames),
        isEmpty,
        reason:
            'Add these to generatedAppDependencyNames in '
            'lib/src/package_name.dart.',
      );
    });
  });

  group('isValidOrg', () {
    test('accepts dot-separated identifier segments', () {
      expect(isValidOrg('com.example'), isTrue);
      expect(isValidOrg('dev.my_org.apps'), isTrue);
      expect(isValidOrg('io.x1'), isTrue);
      expect(isValidOrg('com'), isTrue);
    });

    test('rejects malformed organization identifiers', () {
      expect(isValidOrg(''), isFalse);
      expect(isValidOrg('bad org'), isFalse);
      expect(isValidOrg('1com.x'), isFalse);
      expect(isValidOrg('com.'), isFalse);
      expect(isValidOrg('com..x'), isFalse);
      expect(isValidOrg('.com'), isFalse);
      expect(isValidOrg('com.-x'), isFalse);
    });
  });

  group('humanizePackageName', () {
    test('title-cases underscore-separated parts', () {
      expect(humanizePackageName('my_cool_app'), 'My Cool App');
      expect(humanizePackageName('app'), 'App');
      expect(humanizePackageName('_private'), 'Private');
    });
  });
}
