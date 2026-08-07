import 'dart:convert';
import 'dart:io';

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

    void write(String relative, String contents) {
      File(p.join(project.path, p.joinAll(p.posix.split(relative))))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(contents);
    }

    String read(String relative) => File(
      p.join(project.path, p.joinAll(p.posix.split(relative))),
    ).readAsStringSync();

    setUp(() {
      temp = Directory.systemTemp.createTempSync('fluframe_scaffold_');
      project = Directory(p.join(temp.path, 'demo_app'))..createSync();
      write('pubspec.yaml', 'name: demo_app\nversion: 1.0.0+1\n');
      write('.fluframe.json', '{"schema":1}');
      write(routerPath, _router);
      for (final locale in FeatureScaffold.locales) {
        write(
          'lib/l10n/app_$locale.arb',
          '{\n  "@@locale": "$locale",\n  "settingsTab": "Settings"\n}\n',
        );
      }
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

    test('a multi-word name becomes a PascalCase class', () {
      run('order_history');

      expect(
        read('lib/features/order_history/data/order_history_repository.dart'),
        contains('class OrderHistoryRepository'),
      );
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
  });
}
