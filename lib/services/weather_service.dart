import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/dashboard_weather_snapshot.dart';
import '../models/weather_info.dart';
import 'weather_location_resolver.dart';

typedef WeatherLocationResolver = Future<WeatherCoordinates?> Function();
typedef SharedPreferencesLoader = Future<SharedPreferences?> Function();

/// Open-Meteo を利用した天気取得・キャッシュ
class WeatherService {
  WeatherService({
    http.Client? client,
    WeatherLocationResolver? resolveCurrentLocation,
    SharedPreferencesLoader? loadPreferences,
  })  : _client = client ?? http.Client(),
        _resolveCurrentLocation =
            resolveCurrentLocation ?? resolveCurrentWeatherLocation,
        _loadPreferences = loadPreferences ?? SharedPreferences.getInstance;

  static const cacheKey = 'flowdo_weather_cache';
  static const cacheMaxAge = Duration(minutes: 30);

  static const tokyoLatitude = 35.6895;
  static const tokyoLongitude = 139.6917;
  static const tokyoCity = '東京';

  final http.Client _client;
  final WeatherLocationResolver _resolveCurrentLocation;
  final SharedPreferencesLoader _loadPreferences;

  bool isCacheStale(WeatherInfo cache, {DateTime? referenceNow}) {
    final now = referenceNow ?? DateTime.now();
    return now.difference(cache.updatedAt) >= cacheMaxAge;
  }

  Future<WeatherInfo?> loadCache() async {
    try {
      final prefs = await _loadPreferences();
      final jsonString = prefs?.getString(cacheKey);
      if (jsonString == null || jsonString.isEmpty) return null;

      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) return null;
      return WeatherInfo.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCache(WeatherInfo info) async {
    try {
      final prefs = await _loadPreferences();
      if (prefs == null) return;
      await prefs.setString(cacheKey, jsonEncode(info.toJson()));
    } catch (_) {
      // 保存失敗時は黙ってスキップ
    }
  }

  Future<WeatherInfo> fetchWeather({
    required double latitude,
    required double longitude,
    required String city,
    DateTime? referenceNow,
  }) async {
    final forecastUri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'current': 'temperature_2m,weather_code',
      'hourly': 'precipitation_probability',
      'timezone': 'auto',
      'forecast_days': '1',
    });

    final response = await _client.get(forecastUri);
    if (response.statusCode != 200) {
      throw WeatherFetchException('forecast status ${response.statusCode}');
    }

    final body = _decodeJsonBody(response.bodyBytes);
    final current = body['current'] as Map<String, dynamic>?;
    if (current == null) {
      throw WeatherFetchException('missing current weather');
    }

    final precipitationProbability = _readCurrentHourPrecipitationProbability(
      body,
      referenceNow: referenceNow,
    );

    return WeatherInfo(
      temperature: (current['temperature_2m'] as num).toDouble(),
      weatherCode: current['weather_code'] as int,
      precipitationProbability: precipitationProbability,
      city: city,
      updatedAt: referenceNow ?? DateTime.now(),
    );
  }

  Future<String?> resolveCityName({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/reverse', {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'language': 'ja',
      'count': '1',
    });

    final response = await _client.get(uri);
    if (response.statusCode != 200) return null;

    final body = _decodeJsonBody(response.bodyBytes);
    final results = body['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) return null;

    final first = results.first as Map<String, dynamic>;
    final name = first['name'] as String?;
    if (name == null || name.isEmpty) return null;
    return name;
  }

  Future<DashboardWeatherSnapshot> loadDashboardWeather({
    required bool useCurrentLocation,
    DateTime? referenceNow,
  }) async {
    final now = referenceNow ?? DateTime.now();
    final cached = await loadCache();
    if (cached != null && !isCacheStale(cached, referenceNow: now)) {
      return DashboardWeatherSnapshot.fromWeatherInfo(cached);
    }

    try {
      var latitude = tokyoLatitude;
      var longitude = tokyoLongitude;
      var city = tokyoCity;

      if (useCurrentLocation) {
        final coordinates = await _resolveCurrentLocation();
        if (coordinates != null) {
          latitude = coordinates.latitude;
          longitude = coordinates.longitude;
          city = await resolveCityName(
                latitude: latitude,
                longitude: longitude,
              ) ??
              city;
        }
      }

      final info = await fetchWeather(
        latitude: latitude,
        longitude: longitude,
        city: city,
        referenceNow: now,
      );
      await saveCache(info);
      return DashboardWeatherSnapshot.fromWeatherInfo(info);
    } catch (_) {
      if (cached != null) {
        return DashboardWeatherSnapshot.fromWeatherInfo(cached);
      }
      return DashboardWeatherSnapshot.unavailable;
    }
  }

  int _readCurrentHourPrecipitationProbability(
    Map<String, dynamic> body, {
    DateTime? referenceNow,
  }) {
    final hourly = body['hourly'] as Map<String, dynamic>?;
    if (hourly == null) return 0;

    final times = hourly['time'] as List<dynamic>?;
    final probabilities = hourly['precipitation_probability'] as List<dynamic>?;
    if (times == null ||
        probabilities == null ||
        times.isEmpty ||
        probabilities.isEmpty) {
      return 0;
    }

    final now = referenceNow ?? DateTime.now();
    final targetHour = DateTime(now.year, now.month, now.day, now.hour);

    for (var i = 0; i < times.length && i < probabilities.length; i++) {
      final parsed = DateTime.tryParse(times[i] as String);
      if (parsed == null) continue;
      if (parsed.year == targetHour.year &&
          parsed.month == targetHour.month &&
          parsed.day == targetHour.day &&
          parsed.hour == targetHour.hour) {
        return (probabilities[i] as num).round();
      }
    }

    return (probabilities.first as num).round();
  }

  Map<String, dynamic> _decodeJsonBody(List<int> bytes) {
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }
}

class WeatherFetchException implements Exception {
  WeatherFetchException(this.message);

  final String message;

  @override
  String toString() => 'WeatherFetchException: $message';
}
