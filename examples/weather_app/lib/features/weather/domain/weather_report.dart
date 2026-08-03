import 'package:freezed_annotation/freezed_annotation.dart';

part 'weather_report.freezed.dart';

/// Current weather at a location (subset of Open-Meteo's response).
@freezed
abstract class WeatherReport with _$WeatherReport {
  /// Creates a [WeatherReport].
  const factory WeatherReport({
    required double temperatureC,
    required double windSpeedKmh,
  }) = _WeatherReport;
}

/// A selectable city with fixed coordinates.
enum City {
  /// Seoul, South Korea.
  seoul(37.57, 126.98),

  /// Tokyo, Japan.
  tokyo(35.68, 139.69),

  /// New York, USA.
  newYork(40.71, -74.01);

  const City(this.latitude, this.longitude);

  /// Latitude in degrees.
  final double latitude;

  /// Longitude in degrees.
  final double longitude;
}
