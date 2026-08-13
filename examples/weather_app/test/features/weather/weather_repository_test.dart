import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:weather_app/core/network/api_exception.dart';
import 'package:weather_app/features/weather/data/weather_repository.dart';
import 'package:weather_app/features/weather/domain/weather_report.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  const endpoint = 'https://api.open-meteo.com/v1/forecast';

  group('WeatherRepository', () {
    late _MockDio dio;
    late WeatherRepository repository;

    setUp(() {
      dio = _MockDio();
      repository = WeatherRepository(dio);
    });

    test('parses the current weather', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          endpoint,
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: <String, dynamic>{
            'current_weather': <String, dynamic>{
              'temperature': 15.3,
              'windspeed': 8.4,
            },
          },
          requestOptions: RequestOptions(path: endpoint),
          statusCode: 200,
        ),
      );

      final report = await repository.fetchCurrent(City.seoul);

      expect(
        report,
        const WeatherReport(temperatureC: 15.3, windSpeedKmh: 8.4),
      );
    });

    test('rejects an unexpected response shape', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          endpoint,
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: <String, dynamic>{'nope': true},
          requestOptions: RequestOptions(path: endpoint),
          statusCode: 200,
        ),
      );

      expect(
        () => repository.fetchCurrent(City.seoul),
        throwsA(isA<UnknownApiException>()),
      );
    });

    test('maps timeouts to NetworkException', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          endpoint,
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: endpoint),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      expect(
        () => repository.fetchCurrent(City.seoul),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
