import 'package:fluframe/src/command_runner.dart';
import 'package:test/test.dart';

void main() {
  group('FluframeCommandRunner', () {
    test('--version exits successfully', () async {
      final runner = FluframeCommandRunner();

      expect(await runner.run(['--version']), 0);
    });

    test('create without a project name is a usage error', () async {
      final runner = FluframeCommandRunner();

      expect(await runner.run(['create']), 64);
    });

    test('create rejects an invalid project name', () async {
      final runner = FluframeCommandRunner();

      expect(await runner.run(['create', 'BadName']), 64);
    });

    test('create rejects names that would break generation', () async {
      final runner = FluframeCommandRunner();

      // Each of these used to be accepted, and generation then failed
      // after writing the whole project.
      expect(await runner.run(['create', 'dio']), 64);
      expect(await runner.run(['create', 'shared_preferences']), 64);
      expect(await runner.run(['create', 'firebase_core']), 64);
      expect(await runner.run(['create', 'con']), 64);
      expect(await runner.run(['create', '_private']), 64);
    });

    test('create rejects an invalid --org before running anything', () async {
      final runner = FluframeCommandRunner();

      expect(await runner.run(['create', 'my_app', '--org', 'bad org']), 64);
      expect(await runner.run(['create', 'my_app', '--org', '1com.x']), 64);
    });

    test('unknown commands are usage errors', () async {
      final runner = FluframeCommandRunner();

      expect(await runner.run(['nope']), 64);
    });
  });
}
