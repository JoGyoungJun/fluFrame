import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:weather_app/features/weather/data/weather_repository.dart';
import 'package:weather_app/features/weather/domain/weather_report.dart';

/// The city whose weather is shown.
class SelectedCityController extends Notifier<City> {
  @override
  City build() => City.seoul;

  /// The selected city.
  City get city => state;

  /// Switches the selected city.
  set city(City value) => state = value;
}

/// Provider for the selected city.
final selectedCityProvider = NotifierProvider<SelectedCityController, City>(
  SelectedCityController.new,
);

/// Current weather for the selected city.
final FutureProviderFamily<WeatherReport, City> weatherProvider = FutureProvider
    .autoDispose
    .family<WeatherReport, City>(
      (ref, city) => ref.watch(weatherRepositoryProvider).fetchCurrent(city),
    );
