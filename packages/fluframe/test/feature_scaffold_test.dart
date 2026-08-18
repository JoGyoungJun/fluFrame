import 'dart:convert';
import 'dart:io';

import 'package:fluframe/src/command_runner.dart';
import 'package:fluframe/src/commands/add_command.dart';
import 'package:fluframe/src/feature_scaffold.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// A router with the three anchors, close enough in shape to the real one
/// that a wrong insertion point is visible in the assertions.
const _router = '''
import 'package:demo_app/app/router/route_not_found_screen.dart';
import 'package:demo_app/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      // fluframe:routes — inserts here.
      StatefulShellRoute.indexedStack(
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
          // fluframe:branches — inserts here.
        ],
      ),
    ],
  );
  return router;
});

class AppNavigationShell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: NavigationBar(
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            label: l10n.settingsTab,
          ),
          // fluframe:destinations — inserts here.
        ],
      ),
    );
  }
}
''';

void main() {
  group('FeatureScaffold', () {
    late Directory temp;
    late Directory project;

    void writeInto(Directory root, String relative, String contents) {
      File(p.join(root.path, p.joinAll(p.posix.split(relative))))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(contents);
    }

    void write(String relative, String contents) =>
        writeInto(project, relative, contents);

    /// Seeds [root] with exactly what the app under test starts from, so a
    /// control app built for comparison cannot drift away from it.
    void seed(Directory root) {
      writeInto(root, 'pubspec.yaml', 'name: demo_app\nversion: 1.0.0+1\n');
      writeInto(root, '.fluframe.json', '{"schema":1}');
      writeInto(root, routerPath, _router);
      for (final locale in FeatureScaffold.locales) {
        writeInto(
          root,
          'lib/l10n/app_$locale.arb',
          '{\n  "@@locale": "$locale",\n  "settingsTab": "Settings"\n}\n',
        );
      }
    }

    String read(String relative) => File(
      p.join(project.path, p.joinAll(p.posix.split(relative))),
    ).readAsStringSync();

    setUp(() {
      temp = Directory.systemTemp.createTempSync('fluframe_scaffold_');
      project = Directory(p.join(temp.path, 'demo_app'))..createSync();
      seed(project);
    });

    tearDown(() => temp.deleteSync(recursive: true));

    FeatureScaffold scaffold() => FeatureScaffold(projectDir: project);

    void run(String name, {bool tab = false}) {
      final instance = scaffold();
      instance.apply(
        instance.plan(name: name, tab: tab),
        name: name,
      );
    }

    test('creates the feature module using the app package name', () {
      run('billing');

      expect(
        read('lib/features/billing/data/billing_repository.dart'),
        contains('class BillingRepository'),
      );
      expect(
        read('lib/features/billing/presentation/billing_controller.dart'),
        contains("import 'package:demo_app/features/billing/data/"),
        reason: 'imports must use the app package, never fluframe_app',
      );
      for (final path in [
        'lib/features/billing/presentation/billing_screen.dart',
        'test/features/billing/billing_controller_test.dart',
        'test/features/billing/billing_screen_test.dart',
      ]) {
        expect(
          File(
            p.join(project.path, p.joinAll(p.posix.split(path))),
          ).existsSync(),
          isTrue,
          reason: '$path should exist',
        );
      }
      expect(
        read('lib/features/billing/presentation/billing_screen.dart'),
        isNot(contains('fluframe_app')),
      );
    });

    test('the generated screen caps its rows when the app has the widget', () {
      // Design spec 005: this is what closes the "a new feature could
      // forget the cap" gap that argued for an app-level constraint.
      write('lib/core/widgets/content_width.dart', 'class ContentWidth {}\n');

      run('billing');

      final screen = read(
        'lib/features/billing/presentation/billing_screen.dart',
      );
      expect(
        screen,
        contains("import 'package:demo_app/core/widgets/content_width.dart';"),
      );
      expect(screen, contains('ContentWidth.insetFor'));
      // The import block is re-sorted by nothing here — directives_ordering
      // is fatal in the generated app, so the position matters.
      final imports = const LineSplitter()
          .convert(screen)
          .where((line) => line.startsWith('import '))
          .toList();
      expect(imports, orderedEquals(List<String>.from(imports)..sort()));
    });

    test('the generated screen omits the cap in an app without the widget', () {
      // `add feature` runs inside apps generated by older fluframe
      // versions. Importing a file they do not have would leave them not
      // compiling, which is worse than an uncapped screen.
      run('billing');

      final screen = read(
        'lib/features/billing/presentation/billing_screen.dart',
      );
      expect(screen, isNot(contains('content_width.dart')));
      expect(screen, isNot(contains('ContentWidth')));
      expect(screen, contains('ListView('));
    });

    test('a user-added locale gets the keys too', () {
      // #182: the locale list was hardcoded to en/ja/ko, so an app whose
      // user added app_de.arb got its extra locale silently skipped — and
      // the app ships arb_parity_test.dart, which requires every ARB to
      // carry the same keys. Success exit, red CI.
      write(
        'lib/l10n/app_de.arb',
        '{\n  "@@locale": "de",\n  "settingsTab": "Einstellungen"\n}\n',
      );

      final instance = scaffold();
      final plan = instance.plan(name: 'billing', tab: true);
      instance.apply(plan, name: 'billing');

      final de =
          jsonDecode(read('lib/l10n/app_de.arb')) as Map<String, Object?>;
      expect(de['billingTitle'], 'Billing');
      expect(de['billingTab'], 'Billing');
      // And it is flagged as untranslated, like ja and ko.
      expect(
        plan.untranslated.keys,
        containsAll(['lib/l10n/app_de.arb', 'lib/l10n/app_ja.arb']),
      );
    });

    test('an edited existing file keeps its CRLF line endings', () {
      // #185: the plan's content is LF, and writing it back verbatim
      // rewrote every line of a CRLF router and all ARBs — one 14-line
      // insertion became a 400-line diff.
      write(routerPath, _router.replaceAll('\n', '\r\n'));

      run('billing', tab: true);

      final router = File(
        p.join(project.path, p.joinAll(p.posix.split(routerPath))),
      ).readAsStringSync();
      expect(router, contains('\r\n'));
      expect(
        router.replaceAll('\r\n', '').contains('\n'),
        isFalse,
        reason: 'no mixed endings — every line stays CRLF',
      );
      expect(router, contains('BillingScreen'));
      // The LF ARBs seeded by setUp stay LF: the ending follows each
      // file, not the platform.
      expect(read('lib/l10n/app_en.arb'), isNot(contains('\r\n')));
    });

    test('a missing pubspec is a sentence, not a crash', () {
      // #188: _checkIsFluframeApp passes on .fluframe.json alone, and
      // _readPackageName then died in readAsStringSync with a
      // PathNotFoundException labelled "This is a bug".
      File(p.join(project.path, 'pubspec.yaml')).deleteSync();

      expect(
        () => scaffold().plan(name: 'billing', tab: false),
        throwsA(
          isA<FeatureScaffoldException>().having(
            (e) => e.message,
            'message',
            contains('no pubspec.yaml'),
          ),
        ),
      );
    });

    test('a multi-word name becomes a PascalCase class', () {
      run('order_history');

      expect(
        read('lib/features/order_history/data/order_history_repository.dart'),
        contains('class OrderHistoryRepository'),
      );
    });

    test('a multi-word name produces lowerCamelCase identifiers', () {
      // #162: the raw snake_case name used to be interpolated straight
      // into every provider and ARB key, so `order_historyControllerProvider`
      // tripped non_constant_identifier_names and the generated app failed
      // its own `flutter analyze`. Every single-word test above passes
      // either way, which is why this went unnoticed.
      final instance = scaffold();
      final plan = instance.plan(name: 'order_history', tab: true);
      instance.apply(plan, name: 'order_history');

      expect(
        read('lib/features/order_history/data/order_history_repository.dart'),
        contains('final orderHistoryRepositoryProvider ='),
      );
      final controller = read(
        'lib/features/order_history/presentation/order_history_controller.dart',
      );
      expect(controller, contains('final orderHistoryControllerProvider ='));
      expect(controller, contains('orderHistoryRepositoryProvider'));
      expect(
        controller,
        isNot(
          contains(
            'order_history'
            'Controller',
          ),
        ),
      );

      for (final locale in FeatureScaffold.locales) {
        final arb =
            jsonDecode(read('lib/l10n/app_$locale.arb'))
                as Map<String, Object?>;
        expect(arb, contains('orderHistoryTitle'), reason: locale);
        expect(arb, contains('orderHistoryTab'), reason: locale);
      }
      expect(read(routerPath), contains('l10n.orderHistoryTab'));
    });

    test('scaffolded files import in sorted order for any package name', () {
      // #163: the templates hardcoded the package import above the flutter
      // ones, which is correct only for a name sorting before `flutter` —
      // the template's own `fluframe_app` does, `my_app` does not, and
      // `directives_ordering` is fatal in the generated app.
      for (final package in ['alpha_app', 'my_app', 'zz_app']) {
        write('pubspec.yaml', 'name: $package\nversion: 1.0.0+1\n');
        final instance = scaffold();
        instance.apply(
          instance.plan(name: 'billing', tab: false),
          name: 'billing',
        );

        for (final path in [
          'lib/features/billing/presentation/billing_controller.dart',
          'lib/features/billing/presentation/billing_screen.dart',
          'test/features/billing/billing_controller_test.dart',
          'test/features/billing/billing_screen_test.dart',
        ]) {
          // Per run, not across the file: the test sources put their
          // relative `../../helpers/helpers.dart` import in its own group
          // after a blank line, which is what dart fix produces — a
          // whole-file sort would demand it first.
          var run = <String>[];
          void check() {
            expect(
              run,
              orderedEquals(List<String>.from(run)..sort()),
              reason: '$path in a project named $package',
            );
            run = [];
          }

          for (final line in const LineSplitter().convert(read(path))) {
            if (line.startsWith('import ')) {
              run.add(line);
            } else {
              check();
            }
          }
          check();
        }

        Directory(p.join(project.path, 'lib', 'features')).deleteSync(
          recursive: true,
        );
        Directory(p.join(project.path, 'test', 'features')).deleteSync(
          recursive: true,
        );
        seed(project);
      }
    });

    test('without --tab it registers a route above the shell', () {
      run('billing');

      final router = read(routerPath);
      final routeAt = router.indexOf("path: '/billing'");
      expect(routeAt, greaterThan(0));
      expect(
        routeAt,
        lessThan(router.indexOf('StatefulShellRoute')),
        reason: 'a non-tab feature is a full-screen route, above the shell',
      );
      expect(
        router,
        isNot(
          contains(
            'NavigationDestination(\n            icon: '
            'const Icon(Icons.widgets_outlined)',
          ),
        ),
      );
    });

    test('--tab registers a branch and a destination', () {
      run('billing', tab: true);

      final router = read(routerPath);
      expect(router, contains('StatefulShellBranch('));
      expect(router, contains('label: l10n.billingTab'));
      expect(
        router.indexOf("path: '/billing'"),
        greaterThan(router.indexOf('branches: [')),
        reason: 'the branch belongs inside the shell',
      );
      expect(
        router.indexOf('Icons.widgets_outlined'),
        greaterThan(router.indexOf('destinations: [')),
      );
    });

    test('the screen import lands in sorted position', () {
      run('billing');

      final imports = const LineSplitter()
          .convert(read(routerPath))
          .where((line) => line.startsWith('import '))
          .toList();
      const screenImport =
          "import 'package:demo_app/features/billing/presentation/billing_screen.dart';";
      expect(imports, contains(screenImport));
      expect(
        imports,
        orderedEquals(List<String>.from(imports)..sort()),
        reason: 'directives_ordering is fatal in the generated app',
      );
    });

    test('every locale gets the key, and non-English is flagged', () {
      final instance = scaffold();
      final plan = instance.plan(name: 'billing', tab: true);
      instance.apply(plan, name: 'billing');

      for (final locale in FeatureScaffold.locales) {
        final arb =
            jsonDecode(read('lib/l10n/app_$locale.arb'))
                as Map<String, Object?>;
        expect(arb['billingTitle'], 'Billing', reason: locale);
        expect(arb['billingTab'], 'Billing', reason: locale);
      }
      expect(plan.untranslated.keys, hasLength(2));
      expect(plan.untranslated['lib/l10n/app_ja.arb'], [
        'billingTitle',
        'billingTab',
      ]);
      expect(plan.untranslated.containsKey('lib/l10n/app_en.arb'), isFalse);
    });

    test('English metadata describes the key, not its MapEntry', () {
      final instance = scaffold();
      final plan = instance.plan(name: 'billing', tab: true);
      instance.apply(plan, name: 'billing');

      for (final locale in FeatureScaffold.locales) {
        final arb =
            jsonDecode(read('lib/l10n/app_$locale.arb'))
                as Map<String, Object?>;
        // `@@locale` is the ARB locale marker, not per-key metadata.
        final at = arb.keys.where((key) => key.startsWith('@'));
        final described = at.where((key) => !key.startsWith('@@'));
        if (locale != 'en') {
          expect(described, isEmpty, reason: locale);
          continue;
        }
        // The @-block is the ARB file's contract with translators, so a
        // botched interpolation ships as the instruction they read.
        expect(described, ['@billingTitle', '@billingTab']);
        final title = arb['@billingTitle']! as Map<String, Object?>;
        final tab = arb['@billingTab']! as Map<String, Object?>;
        expect(title['description'], 'Label for the billingTitle screen.');
        expect(tab['description'], 'Label for the billingTab screen.');
      }
    });

    test('--dry-run writes nothing', () {
      final before = read(routerPath);

      scaffold().plan(name: 'billing', tab: true);

      expect(read(routerPath), before);
      expect(
        Directory(p.join(project.path, 'lib', 'features')).existsSync(),
        isFalse,
      );
    });

    group('refuses', () {
      test('a directory that is not an app', () {
        final empty = Directory(p.join(temp.path, 'empty'))..createSync();

        expect(
          () => FeatureScaffold(projectDir: empty).plan(
            name: 'billing',
            tab: false,
          ),
          throwsA(
            isA<FeatureScaffoldException>().having(
              (e) => e.message,
              'message',
              contains('not a Flutter app'),
            ),
          ),
        );
      });

      test('an invalid name, explaining which rule it broke', () {
        expect(
          () => scaffold().plan(name: 'Billing', tab: false),
          throwsA(
            isA<FeatureScaffoldException>().having(
              (e) => e.message,
              'message',
              contains('lower_snake_case'),
            ),
          ),
        );
        expect(
          () => scaffold().plan(name: 'class', tab: false),
          throwsA(
            isA<FeatureScaffoldException>().having(
              (e) => e.message,
              'message',
              contains('reserved word'),
            ),
          ),
        );
      });

      test('a feature directory that already exists', () {
        run('billing');

        expect(
          () => scaffold().plan(name: 'billing', tab: false),
          throwsA(
            isA<FeatureScaffoldException>().having(
              (e) => e.message,
              'message',
              contains('already exists'),
            ),
          ),
        );
      });

      test('a test directory that already exists, with no lib sibling', () {
        // Someone who wrote the tests first. Before this guard the scaffold
        // ran happily and overwrote them — and worse, apply's rollback
        // deletes test/features/<name> wholesale, so a later failed write
        // took the whole directory with it.
        write(
          'test/features/billing/billing_controller_test.dart',
          'void main() {}\n// hand written, months of work\n',
        );

        expect(
          () => scaffold().plan(name: 'billing', tab: false),
          throwsA(
            isA<FeatureScaffoldException>().having(
              (e) => e.message,
              'message',
              contains('test/features/billing already exists'),
            ),
          ),
        );
        // The refusal is a refusal: the file is still there, untouched.
        expect(
          read('test/features/billing/billing_controller_test.dart'),
          contains('hand written'),
        );
      });

      test('a router without the anchor, pointing at upgrade', () {
        write(routerPath, 'const nothing = 0;\n');

        expect(
          () => scaffold().plan(name: 'billing', tab: false),
          throwsA(
            isA<FeatureScaffoldException>()
                .having(
                  (e) => e.message,
                  'message',
                  contains('fluframe:routes'),
                )
                .having((e) => e.hint, 'hint', contains('fluframe upgrade')),
          ),
        );
      });

      test('a --tab run when only the routes anchor is present', () {
        write(routerPath, '// fluframe:routes\n');

        expect(
          () => scaffold().plan(name: 'billing', tab: true),
          throwsA(
            isA<FeatureScaffoldException>().having(
              (e) => e.message,
              'message',
              contains('fluframe:branches'),
            ),
          ),
        );
      });

      test('a malformed ARB, naming the file', () {
        write('lib/l10n/app_ko.arb', '{ not json');

        expect(
          () => scaffold().plan(name: 'billing', tab: false),
          throwsA(
            isA<FeatureScaffoldException>().having(
              (e) => e.message,
              'message',
              contains('app_ko.arb'),
            ),
          ),
        );
      });

      test('an ARB holding a JSON array, not an object', () {
        // The same crash class as #187 in .fluframe.json: `as Map` on a
        // decoded array raises a TypeError, which `on FormatException`
        // does not catch and the CLI prints as "This is a bug" + a trace.
        write('lib/l10n/app_ko.arb', '["settingsTab", "Settings"]\n');

        expect(
          () => scaffold().plan(name: 'billing', tab: false),
          throwsA(
            isA<FeatureScaffoldException>().having(
              (e) => e.message,
              'message',
              allOf(contains('app_ko.arb'), contains('not a JSON object')),
            ),
          ),
        );
      });

      test('a key the app already defines', () {
        write(
          'lib/l10n/app_en.arb',
          '{\n  "@@locale": "en",\n  "billingTitle": "Mine"\n}\n',
        );

        expect(
          () => scaffold().plan(name: 'billing', tab: false),
          throwsA(
            isA<FeatureScaffoldException>().having(
              (e) => e.message,
              'message',
              contains('already defines'),
            ),
          ),
        );
      });

      test('every refusal leaves the app untouched', () {
        final routerBefore = read(routerPath);
        write(routerPath, routerBefore.replaceAll('// fluframe:routes', ''));
        final broken = read(routerPath);

        expect(
          () => scaffold().plan(name: 'billing', tab: false),
          throwsA(isA<FeatureScaffoldException>()),
        );

        expect(read(routerPath), broken);
        expect(
          Directory(p.join(project.path, 'lib', 'features')).existsSync(),
          isFalse,
        );
        expect(read('lib/l10n/app_en.arb'), isNot(contains('billingTitle')));
      });
    });

    test('a failed write leaves no half-scaffolded feature', () {
      final instance = scaffold();
      final plan = instance.plan(name: 'billing', tab: false);
      // The router is a directory now, so writing it fails after the
      // feature files have already landed.
      File(
        p.join(project.path, p.joinAll(p.posix.split(routerPath))),
      ).deleteSync();
      Directory(
        p.join(project.path, p.joinAll(p.posix.split(routerPath))),
      ).createSync(recursive: true);

      expect(() => instance.apply(plan, name: 'billing'), throwsA(anything));

      expect(
        Directory(
          p.join(project.path, 'lib', 'features', 'billing'),
        ).existsSync(),
        isFalse,
        reason: 'a feature that does not compile must not be left behind',
      );
      expect(
        Directory(
          p.join(project.path, 'test', 'features', 'billing'),
        ).existsSync(),
        isFalse,
      );
    });

    /// Makes [relative] unwritable while leaving it readable, and returns
    /// the undo. Also registered as a teardown: a read-only file left
    /// behind breaks the temp directory cleanup on Windows.
    void Function() makeReadOnly(String relative) {
      final path = p.join(project.path, p.joinAll(p.posix.split(relative)));
      void clear() {
        if (Platform.isWindows) {
          Process.runSync('attrib', ['-R', path]);
        } else {
          Process.runSync('chmod', ['644', path]);
        }
      }

      final applied = Platform.isWindows
          ? Process.runSync('attrib', ['+R', path])
          : Process.runSync('chmod', ['444', path]);
      expect(applied.exitCode, 0, reason: 'could not mark $relative read-only');
      addTearDown(clear);
      // Without this the test would pass on a filesystem that ignores the
      // flag, having exercised nothing at all.
      expect(
        () => File(path).writeAsStringSync('probe'),
        throwsA(isA<FileSystemException>()),
        reason: 'read-only was not enforced, so this test proves nothing',
      );
      return clear;
    }

    test('a failure at the last ARB write puts the router and every ARB '
        'back', () {
      final instance = scaffold();
      final plan = instance.plan(name: 'billing', tab: true);
      final routerBefore = read(routerPath);
      final arbsBefore = {
        for (final locale in FeatureScaffold.locales)
          'lib/l10n/app_$locale.arb': read('lib/l10n/app_$locale.arb'),
      };
      // app_ko.arb is written last — after the router and the other two
      // ARBs have already been changed. That is the window #123 left open,
      // and the existing test above cannot reach it because it fails at the
      // router step, one write earlier.
      makeReadOnly('lib/l10n/app_ko.arb');

      expect(() => instance.apply(plan, name: 'billing'), throwsA(anything));

      expect(
        read(routerPath),
        routerBefore,
        reason: 'the router kept an import and a route for a deleted class',
      );
      arbsBefore.forEach((relative, contents) {
        expect(read(relative), contents, reason: '$relative was left edited');
      });
      expect(
        Directory(
          p.join(project.path, 'lib', 'features', 'billing'),
        ).existsSync(),
        isFalse,
      );
      expect(
        Directory(
          p.join(project.path, 'test', 'features', 'billing'),
        ).existsSync(),
        isFalse,
      );
    });

    test('a failure the rollback undoes completely is a sentence, not a '
        'bug report', () async {
      // apply()'s two failure arms were reported backwards. An incomplete
      // rollback — the app edited and not compiling — threw a
      // FeatureScaffoldException and got a clean sentence with exit 74.
      // A *complete* one rethrew the io.FileSystemException, which
      // nothing downstream matches: it reached the runner's catch-all as
      // "This is a bug. Please report it", a stack trace and exit 70. The
      // best outcome the failure path has was the only one demanding a
      // bug report from a user whose app is perfectly fine.
      makeReadOnly('lib/l10n/app_ko.arb');
      final err = StringBuffer();
      final runner = FluframeCommandRunner(err: err)
        ..addCommand(AddFeatureCommand(err: err));

      final code = await runner.run([
        'feature',
        'billing',
        '--project-dir',
        project.path,
      ]);

      // 74 = EX_IOERR, the code the other arm already uses: the write
      // failed, and neither the invocation nor fluframe is at fault.
      expect(code, 74, reason: err.toString());
      expect(err.toString(), contains('Adding "billing" failed'));
      expect(err.toString(), contains('Nothing was changed'));
      expect(err.toString(), isNot(contains('This is a bug')));
      expect(err.toString(), isNot(contains('#0')));
      // The sentence has to be true, or it is a worse lie than the trace.
      expect(read(routerPath), _router);
      expect(
        Directory(
          p.join(project.path, 'lib', 'features', 'billing'),
        ).existsSync(),
        isFalse,
      );
    });

    test('a re-run after a failed apply is not refused', () {
      final instance = scaffold();
      final plan = instance.plan(name: 'billing', tab: true);
      final clear = makeReadOnly('lib/l10n/app_ko.arb');
      expect(() => instance.apply(plan, name: 'billing'), throwsA(anything));

      // The operator fixes the permission and runs it again. Before #123
      // this refused with 'app_en.arb already defines "billingTitle"',
      // because the successful ARB writes were never undone.
      clear();
      run('billing', tab: true);

      // Not just "it did not refuse": every file it edits must end up
      // byte-identical to the same scaffold run in an app that never
      // failed. That is what proves the rollback was complete rather than
      // merely enough to get past the refusal checks.
      final control = Directory(p.join(temp.path, 'control_app'))..createSync();
      seed(control);
      final clean = FeatureScaffold(projectDir: control);
      clean.apply(clean.plan(name: 'billing', tab: true), name: 'billing');

      for (final relative in [
        routerPath,
        for (final locale in FeatureScaffold.locales)
          'lib/l10n/app_$locale.arb',
      ]) {
        expect(
          read(relative),
          File(
            p.join(control.path, p.joinAll(p.posix.split(relative))),
          ).readAsStringSync(),
          reason: '$relative differs from a run that never failed',
        );
      }
    });
  });
}
