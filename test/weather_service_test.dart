import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flowdo/models/dashboard_weather_snapshot.dart';
import 'package:flowdo/models/weather_info.dart';
import 'package:flowdo/services/weather_location_resolver.dart';
import 'package:flowdo/services/weather_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final forecastBody = jsonEncode({
    'current': {
      'temperature_2m': 31.2,
      'weather_code': 0,
    },
    'hourly': {
      'time': ['2026-08-14T12:00', '2026-08-14T13:00'],
      'precipitation_probability': [20, 35],
    },
  });

  final reverseBody = jsonEncode({
    'results': [
      {'name': '渋谷区'},
    ],
  });

  http.Response mockUtf8Response(String body, {int statusCode = 200}) {
    return http.Response.bytes(
      utf8.encode(body),
      statusCode,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }

  test('isCacheStale は30分経過で true', () {
    final service = WeatherService(client: MockClient((_) async => http.Response('', 500)));
    final cache = WeatherInfo(
      temperature: 20,
      weatherCode: 0,
      precipitationProbability: 10,
      city: '東京',
      updatedAt: DateTime(2026, 8, 14, 12, 0),
    );

    expect(
      service.isCacheStale(
        cache,
        referenceNow: DateTime(2026, 8, 14, 12, 29),
      ),
      isFalse,
    );
    expect(
      service.isCacheStale(
        cache,
        referenceNow: DateTime(2026, 8, 14, 12, 30),
      ),
      isTrue,
    );
  });

  test('saveCache / loadCache は WeatherInfo を保存する', () async {
    SharedPreferences.setMockInitialValues({});
    final service = WeatherService(client: MockClient((_) async => http.Response('', 500)));
    final info = WeatherInfo(
      temperature: 28,
      weatherCode: 3,
      precipitationProbability: 40,
      city: '東京',
      updatedAt: DateTime(2026, 8, 14, 9, 0),
    );

    await service.saveCache(info);
    final loaded = await service.loadCache();

    expect(loaded?.city, '東京');
    expect(loaded?.weatherCode, 3);
    expect(loaded?.precipitationProbability, 40);
  });

  test('fetchWeather は Open-Meteo レスポンスを解析する', () async {
    final service = WeatherService(
      client: MockClient((request) async {
        expect(request.url.host, 'api.open-meteo.com');
        return mockUtf8Response(forecastBody);
      }),
    );

    final info = await service.fetchWeather(
      latitude: 35.6895,
      longitude: 139.6917,
      city: '東京',
      referenceNow: DateTime(2026, 8, 14, 12, 15),
    );

    expect(info.temperatureCelsius, 31);
    expect(info.weatherCode, 0);
    expect(info.precipitationProbability, 20);
    expect(info.city, '東京');
  });

  test('loadDashboardWeather は新鮮なキャッシュを優先する', () async {
    SharedPreferences.setMockInitialValues({
      WeatherService.cacheKey: jsonEncode(
        WeatherInfo(
          temperature: 25,
          weatherCode: 1,
          precipitationProbability: 5,
          city: 'キャッシュ',
          updatedAt: DateTime(2026, 8, 14, 12, 20),
        ).toJson(),
      ),
    });

    final service = WeatherService(
      client: MockClient((_) async => http.Response('', 500)),
    );

    final snapshot = await service.loadDashboardWeather(
      useCurrentLocation: false,
      referenceNow: DateTime(2026, 8, 14, 12, 25),
    );

    expect(snapshot.locationLabel, 'キャッシュ');
    expect(snapshot.temperatureCelsius, 25);
    expect(snapshot.weatherIconEmoji, '🌤');
  });

  test('loadDashboardWeather は取得失敗時に古いキャッシュを返す', () async {
    SharedPreferences.setMockInitialValues({
      WeatherService.cacheKey: jsonEncode(
        WeatherInfo(
          temperature: 22,
          weatherCode: 3,
          precipitationProbability: 10,
          city: '大阪',
          updatedAt: DateTime(2026, 8, 14, 11, 0),
        ).toJson(),
      ),
    });

    final service = WeatherService(
      client: MockClient((_) async => http.Response('', 500)),
    );

    final snapshot = await service.loadDashboardWeather(
      useCurrentLocation: false,
      referenceNow: DateTime(2026, 8, 14, 12, 0),
    );

    expect(snapshot.locationLabel, '大阪');
    expect(snapshot.temperatureCelsius, 22);
  });

  test('loadDashboardWeather はキャッシュも無い失敗時に unavailable を返す', () async {
    SharedPreferences.setMockInitialValues({});
    final service = WeatherService(
      client: MockClient((_) async => http.Response('', 500)),
    );

    final snapshot = await service.loadDashboardWeather(
      useCurrentLocation: false,
    );

    expect(snapshot, DashboardWeatherSnapshot.unavailable);
  });

  test('resolveCityName は Open-Meteo reverse API から地名を返す', () async {
    final service = WeatherService(
      client: MockClient((request) async {
        expect(request.url.host, 'geocoding-api.open-meteo.com');
        return mockUtf8Response(reverseBody);
      }),
    );

    final city = await service.resolveCityName(
      latitude: 35.66,
      longitude: 139.70,
    );

    expect(city, '渋谷区');
  });

  test('loadDashboardWeather は現在地許可時に取得した天気を保存する', () async {
    SharedPreferences.setMockInitialValues({});
    final requests = <Uri>[];

    final service = WeatherService(
      client: MockClient((request) async {
        requests.add(request.url);
        if (request.url.host == 'geocoding-api.open-meteo.com') {
          return mockUtf8Response(reverseBody);
        }
        if (request.url.host == 'api.open-meteo.com') {
          return mockUtf8Response(forecastBody);
        }
        return http.Response('unexpected ${request.url}', 404);
      }),
      resolveCurrentLocation: () async {
        return const WeatherCoordinates(
          latitude: 35.66,
          longitude: 139.70,
        );
      },
    );

    final snapshot = await service.loadDashboardWeather(
      useCurrentLocation: true,
      referenceNow: DateTime(2026, 8, 14, 12, 0),
    );

    expect(requests, hasLength(2));
    expect(snapshot.locationLabel, '渋谷区');
    expect(snapshot.temperatureCelsius, 31);
    expect(snapshot.precipitationPercent, 20);

    final cached = await service.loadCache();
    expect(cached?.city, '渋谷区');
  });
}
