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

    test('unknown commands are usage errors', () async {
      final runner = FluframeCommandRunner();

      expect(await runner.run(['nope']), 64);
    });
  });
}
