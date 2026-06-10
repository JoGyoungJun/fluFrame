import 'app_exception.dart';

abstract interface class AppConfig {
  String get environmentName;

  String? value(String key);

  String requireValue(String key);
}

final class MapAppConfig implements AppConfig {
  const MapAppConfig({
    required this.environmentName,
    required Map<String, String> values,
  }) : _values = values;

  @override
  final String environmentName;

  final Map<String, String> _values;

  @override
  String? value(String key) => _values[key];

  @override
  String requireValue(String key) {
    final resolved = value(key);
    if (resolved == null || resolved.isEmpty) {
      throw AppException(
        'Missing required config value.',
        code: 'missing_config_value',
        cause: key,
      );
    }
    return resolved;
  }
}
