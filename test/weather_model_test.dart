import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/models/weather_code.dart';
import 'package:flowdo/models/weather_info.dart';

void main() {
  test('weatherCodeToEmoji は WMO code を絵文字へ変換する', () {
    expect(weatherCodeToEmoji(0), '☀️');
    expect(weatherCodeToEmoji(1), '🌤');
    expect(weatherCodeToEmoji(3), '☁️');
    expect(weatherCodeToEmoji(61), '🌧');
    expect(weatherCodeToEmoji(95), '⛈');
    expect(weatherCodeToEmoji(71), '❄️');
  });

  test('WeatherInfo は JSON へ保存・復元できる', () {
    final info = WeatherInfo(
      temperature: 31.4,
      weatherCode: 2,
      precipitationProbability: 20,
      city: '東京',
      updatedAt: DateTime(2026, 8, 14, 12, 30),
    );

    final restored = WeatherInfo.fromJson(info.toJson());

    expect(restored.temperature, 31.4);
    expect(restored.weatherCode, 2);
    expect(restored.precipitationProbability, 20);
    expect(restored.city, '東京');
    expect(restored.updatedAt, info.updatedAt);
    expect(restored.weatherIconEmoji, '🌤');
    expect(restored.temperatureCelsius, 31);
  });
}
