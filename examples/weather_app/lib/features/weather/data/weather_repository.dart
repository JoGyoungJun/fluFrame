import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_app/core/network/api_client.dart';
import 'package:weather_app/core/network/api_exception.dart';
import 'package:weather_app/features/weather/domain/weather_report.dart';

/// Fetches current weather from Open-Meteo (free, no API key).
///
/// Uses an absolute URL, so it works alongside the template's
/// base-URL-configured [dioProvider] without touching it.
class WeatherRepository {
  /// Creates a repository that talks to Open-Meteo through [dio].
  WeatherRepository(Dio dio) : _dio = dio;

  final Dio _dio;

  static const String _endpoint = 'https://api.open-meteo.com/v1/forecast';

  /// Fetches the current weather for [city].
  Future<WeatherReport> fetchCurrent(City city) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _endpoint,
        queryParameters: {
          'latitude': city.latitude,
          'longitude': city.longitude,
          'current_weather': true,
        },
      );
      final current = response.data?['current_weather'];
      if (current is! Map<String, dynamic>) {
        throw const UnknownApiException('Unexpected response shape.');
      }
      return WeatherReport(
        temperatureC: (current['temperature'] as num).toDouble(),
        windSpeedKmh: (current['windspeed'] as num).toDouble(),
      );
    } on DioException catch (exception) {
      throw mapDioException(exception);
    }
  }
}

/// Provider for the app-wide [WeatherRepository].
final weatherRepositoryProvider = Provider<WeatherRepository>(
  (ref) => WeatherRepository(ref.watch(dioProvider)),
);
