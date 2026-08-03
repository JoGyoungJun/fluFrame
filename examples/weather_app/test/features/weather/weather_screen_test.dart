import 'package:flutter_test/flutter_test.dart';
import 'package:weather_app/features/weather/data/weather_repository.dart';
import 'package:weather_app/features/weather/domain/weather_report.dart';
import 'package:weather_app/features/weather/presentation/weather_screen.dart';

import '../../helpers/helpers.dart';

class _FakeWeatherRepository implements WeatherRepository {
  static const Map<City, WeatherReport> reports = {
    City.seoul: WeatherReport(temperatureC: 15.3, windSpeedKmh: 8.4),
    City.tokyo: WeatherReport(temperatureC: 21, windSpeedKmh: 3.2),
    City.newYork: WeatherReport(temperatureC: 9.9, windSpeedKmh: 12.5),
    City.paris: WeatherReport(temperatureC: 18.2, windSpeedKmh: 6.1),
    City.sydney: WeatherReport(temperatureC: 25.4, windSpeedKmh: 14.8),
  };

  @override
  Future<WeatherReport> fetchCurrent(City city) async => reports[city]!;
}

void main() {
  group('WeatherScreen', () {
    testWidgets('shows the current weather for the default city', (
      tester,
    ) async {
      await tester.pumpApp(
        const WeatherScreen(),
        overrides: [
          weatherRepositoryProvider.overrideWith(
            (ref) => _FakeWeatherRepository(),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('15.3°C'), findsOneWidget);
      expect(find.text('Wind 8.4 km/h'), findsOneWidget);
    });

    testWidgets('switching city fetches its weather', (tester) async {
      await tester.pumpApp(
        const WeatherScreen(),
        overrides: [
          weatherRepositoryProvider.overrideWith(
            (ref) => _FakeWeatherRepository(),
          ),
        ],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tokyo'));
      await tester.pumpAndSettle();

      expect(find.text('21.0°C'), findsOneWidget);
    });

    testWidgets('the new cities fetch their own weather', (tester) async {
      await tester.pumpApp(
        const WeatherScreen(),
        overrides: [
          weatherRepositoryProvider.overrideWith(
            (ref) => _FakeWeatherRepository(),
          ),
        ],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sydney'));
      await tester.pumpAndSettle();

      expect(find.text('25.4°C'), findsOneWidget);
    });
  });
}
