import 'package:fulframe_core/fulframe_core.dart';
import 'package:test/test.dart';

void main() {
  test('MapAppConfig returns environment and values', () {
    const config = MapAppConfig(
      environmentName: 'test',
      values: {'apiBaseUrl': 'https://example.test'},
    );

    expect(config.environmentName, 'test');
    expect(config.value('apiBaseUrl'), 'https://example.test');
  });

  test('requireValue throws AppException for missing value', () {
    const config = MapAppConfig(environmentName: 'test', values: {});

    expect(
      () => config.requireValue('apiBaseUrl'),
      throwsA(isA<AppException>()),
    );
  });
}
