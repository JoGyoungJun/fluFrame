import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_app/core/widgets/async_value_widget.dart';
import 'package:weather_app/core/widgets/content_width.dart';
import 'package:weather_app/features/weather/domain/weather_report.dart';
import 'package:weather_app/features/weather/presentation/weather_controller.dart';
import 'package:weather_app/l10n/gen/app_localizations.dart';

/// Current weather for a selectable city (Open-Meteo, no API key).
class WeatherScreen extends ConsumerWidget {
  /// Creates the weather screen.
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final city = ref.watch(selectedCityProvider);
    final weather = ref.watch(weatherProvider(city));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.weatherTitle)),
      body: ContentWidth(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SegmentedButton<City>(
                segments: [
                  ButtonSegment(
                    value: City.seoul,
                    label: Text(l10n.citySeoul),
                  ),
                  ButtonSegment(
                    value: City.tokyo,
                    label: Text(l10n.cityTokyo),
                  ),
                  ButtonSegment(
                    value: City.newYork,
                    label: Text(l10n.cityNewYork),
                  ),
                  ButtonSegment(
                    value: City.paris,
                    label: Text(l10n.cityParis),
                  ),
                  ButtonSegment(
                    value: City.sydney,
                    label: Text(l10n.citySydney),
                  ),
                ],
                selected: {city},
                onSelectionChanged: (selection) =>
                    ref.read(selectedCityProvider.notifier).city =
                        selection.first,
              ),
            ),
            Expanded(
              child: AsyncValueWidget<WeatherReport>(
                value: weather,
                onRetry: () => ref.invalidate(weatherProvider(city)),
                messageOf: (error) => l10n.weatherErrorMessage,
                data: (report) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.temperatureValue(report.temperatureC),
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.windValue(report.windSpeedKmh),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
