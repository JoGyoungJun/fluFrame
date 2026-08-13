import 'dart:io';

import 'package:fluframe/src/bundle_hygiene.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('GitignoreMatcher', () {
    test('matches the rule guarding the documented secret location', () {
      final matcher = GitignoreMatcher.parse('env/*.local.json\n');

      expect(matcher.ignores('env/dev.local.json'), isTrue);
      expect(matcher.ignores('env/prod.local.json'), isTrue);
      // The committed defaults must survive — they are the whole point of
      // shipping env/ at all.
      expect(matcher.ignores('env/dev.json'), isFalse);
      expect(matcher.ignores('env/prod.json'), isFalse);
    });

    test('a pattern containing a slash is anchored to the root', () {
      final matcher = GitignoreMatcher.parse('env/*.local.json\n');

      expect(matcher.ignores('lib/env/dev.local.json'), isFalse);
    });

    test('a pattern without a slash matches at any depth', () {
      final matcher = GitignoreMatcher.parse('*.log\n');

      expect(matcher.ignores('build.log'), isTrue);
      expect(matcher.ignores('lib/core/network/trace.log'), isTrue);
      expect(matcher.ignores('lib/logger.dart'), isFalse);
    });

    test('a leading slash anchors to the root only', () {
      final matcher = GitignoreMatcher.parse('/build/\n');

      expect(matcher.ignores('build', isDirectory: true), isTrue);
      expect(matcher.ignores('lib/build', isDirectory: true), isFalse);
    });

    test('a trailing slash restricts the rule to directories', () {
      final matcher = GitignoreMatcher.parse('.idea/\n');

      expect(matcher.ignores('.idea', isDirectory: true), isTrue);
      // A *file* called .idea is not what the rule describes.
      expect(matcher.ignores('.idea'), isFalse);
    });

    test('leading ** matches at the root and at any depth', () {
      final matcher = GitignoreMatcher.parse('**/doc/api/\n');

      expect(matcher.ignores('doc/api', isDirectory: true), isTrue);
      expect(matcher.ignores('lib/x/doc/api', isDirectory: true), isTrue);
      expect(matcher.ignores('doc/apidocs', isDirectory: true), isFalse);
    });

    test('a deep literal path matches at any depth', () {
      final matcher = GitignoreMatcher.parse(
        '**/ios/Flutter/.last_build_id\n',
      );

      expect(matcher.ignores('ios/Flutter/.last_build_id'), isTrue);
      expect(matcher.ignores('a/b/ios/Flutter/.last_build_id'), isTrue);
      expect(matcher.ignores('ios/Flutter/other'), isFalse);
    });

    test('? matches exactly one character, never a separator', () {
      final matcher = GitignoreMatcher.parse('app.?.map\n');

      expect(matcher.ignores('app.1.map'), isTrue);
      expect(matcher.ignores('app.12.map'), isFalse);
      expect(matcher.ignores('app./.map'), isFalse);
    });

    test('* does not cross a separator', () {
      final matcher = GitignoreMatcher.parse('lib/*.dart\n');

      expect(matcher.ignores('lib/main.dart'), isTrue);
      expect(matcher.ignores('lib/features/main.dart'), isFalse);
    });

    test('comments and blank lines carry no rule', () {
      final matcher = GitignoreMatcher.parse('''
# *.dart


''');

      expect(matcher.ignores('lib/main.dart'), isFalse);
    });

    test('a later ! rule re-includes what an earlier rule ignored', () {
      final matcher = GitignoreMatcher.parse('.env.*\n!.env.example\n');

      expect(matcher.ignores('.env.production'), isTrue);
      expect(matcher.ignores('.env.example'), isFalse);
    });

    test('order matters — a re-ignore after a ! wins', () {
      final matcher = GitignoreMatcher.parse('!.env.example\n.env.*\n');

      expect(matcher.ignores('.env.example'), isTrue);
    });

    test('accepts backslash separators, so Windows paths match', () {
      final matcher = GitignoreMatcher.parse('env/*.local.json\n');

      expect(matcher.ignores(r'env\dev.local.json'), isTrue);
    });
  });

  group('the real template/.gitignore', () {
    // The sync reads this file as its filter. Both directions are load
    // bearing: missing the secret rule ships a credential, and matching one
    // file too many silently drops it from the published bundle, where the
    // only existing guard is that test/ is non-empty.
    late GitignoreMatcher matcher;

    setUpAll(() {
      final file = File(
        p.normalize(
          p.join(Directory.current.path, '..', '..', 'template', '.gitignore'),
        ),
      );
      expect(
        file.existsSync(),
        isTrue,
        reason: 'run from packages/fluframe; sync_template reads the same path',
      );
      matcher = GitignoreMatcher.parse(file.readAsStringSync());
    });

    test('excludes the documented secret location', () {
      expect(matcher.ignores('env/dev.local.json'), isTrue);
      expect(matcher.ignores('env/prod.local.json'), isTrue);
    });

    test('keeps every kind of file the bundle must ship', () {
      const mustShip = [
        'pubspec.yaml',
        'analysis_options.yaml',
        'l10n.yaml',
        'README.md',
        'AGENTS.md',
        'env/dev.json',
        'env/prod.json',
        'lib/main.dart',
        'lib/app/app.dart',
        'lib/app/router/app_router.dart',
        'lib/features/posts/domain/post.freezed.dart',
        'lib/features/posts/domain/post.g.dart',
        'lib/l10n/app_en.arb',
        'lib/l10n/app_ja.arb',
        'lib/l10n/app_ko.arb',
        'lib/l10n/gen/app_localizations.dart',
        'test/main_test.dart',
        'test/l10n/arb_parity_test.dart',
        'test/helpers/helpers.dart',
        '.github/workflows/ci.yml',
      ];

      for (final path in mustShip) {
        expect(
          matcher.ignores(path),
          isFalse,
          reason: '$path would be dropped from the published bundle',
        );
      }
    });

    test('keeps the directories the walk descends into', () {
      for (final dir in ['lib', 'test', 'env', '.github', 'lib/l10n']) {
        expect(
          matcher.ignores(dir, isDirectory: true),
          isFalse,
          reason: '$dir would be pruned, taking everything under it',
        );
      }
    });
  });

  group('findSecretLikeFiles', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('fluframe_hygiene_');
      addTearDown(() {
        try {
          root.deleteSync(recursive: true);
        } on FileSystemException {
          // Windows can hold a lock briefly; a leaked temp dir is harmless.
        }
      });
    });

    void write(String relative) {
      File(p.join(root.path, p.joinAll(relative.split('/'))))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('x');
    }

    test('is empty for a bundle that carries only template sources', () {
      write('app/lib/main.dart');
      write('app/env/dev.json');
      write('app/env/prod.json');
      write('addons/firebase/lib/firebase_options.dart');

      expect(findSecretLikeFiles(root), isEmpty);
    });

    test('finds the secret shapes at any depth, including the addons', () {
      write('app/env/dev.local.json');
      write('addons/firebase/env/prod.local.json');
      write('app/.env');
      write('app/ios/certs/dist.pem');
      write('app/android/upload.jks');
      write('app/.ssh/id_rsa');
      write('app/service-account-prod.json');

      expect(findSecretLikeFiles(root), [
        'addons/firebase/env/prod.local.json',
        'app/.env',
        'app/.ssh/id_rsa',
        'app/android/upload.jks',
        'app/env/dev.local.json',
        'app/ios/certs/dist.pem',
        'app/service-account-prod.json',
      ]);
    });

    test('leaves the example env files alone', () {
      write('app/.env.example');
      write('app/.env.sample');
      write('app/.env.template');

      expect(findSecretLikeFiles(root), isEmpty);
    });

    test('reports nothing for a directory that does not exist', () {
      expect(
        findSecretLikeFiles(Directory(p.join(root.path, 'absent'))),
        isEmpty,
      );
    });
  });
}
