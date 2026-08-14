import 'weather_code.dart';
import 'weather_info.dart';

/// Dashboard 天気カード表示用スナップショット
class DashboardWeatherSnapshot {
  const DashboardWeatherSnapshot({
    this.locationLabel = '東京',
    this.temperatureCelsius = 31,
    this.precipitationPercent = 10,
    this.weatherIconEmoji = '☀️',
    this.isUnavailable = false,
    this.showPrecipitation = true,
  });

  final String locationLabel;
  final int temperatureCelsius;
  final int precipitationPercent;
  final String weatherIconEmoji;
  final bool isUnavailable;
  final bool showPrecipitation;

  static const fallback = DashboardWeatherSnapshot();

  static const unavailable = DashboardWeatherSnapshot(
    locationLabel: '天気を取得できませんでした',
    temperatureCelsius: 0,
    precipitationPercent: 0,
    weatherIconEmoji: '🌤',
    isUnavailable: true,
    showPrecipitation: false,
  );

  factory DashboardWeatherSnapshot.fromWeatherInfo(WeatherInfo info) {
    return DashboardWeatherSnapshot(
      locationLabel: info.city,
      temperatureCelsius: info.temperatureCelsius,
      precipitationPercent: info.precipitationProbability,
      weatherIconEmoji: weatherCodeToEmoji(info.weatherCode),
    );
  }
}
