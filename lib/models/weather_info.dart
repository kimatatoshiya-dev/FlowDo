import 'weather_code.dart';

/// Open-Meteo から取得した天気情報
class WeatherInfo {
  const WeatherInfo({
    required this.temperature,
    required this.weatherCode,
    required this.precipitationProbability,
    required this.city,
    required this.updatedAt,
  });

  final double temperature;
  final int weatherCode;
  final int precipitationProbability;
  final String city;
  final DateTime updatedAt;

  String get weatherIconEmoji => weatherCodeToEmoji(weatherCode);

  int get temperatureCelsius => temperature.round();

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'weatherCode': weatherCode,
      'precipitationProbability': precipitationProbability,
      'city': city,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory WeatherInfo.fromJson(Map<String, dynamic> json) {
    return WeatherInfo(
      temperature: (json['temperature'] as num).toDouble(),
      weatherCode: json['weatherCode'] as int,
      precipitationProbability: json['precipitationProbability'] as int,
      city: json['city'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

/// ローカルキャッシュ用（WeatherInfo と同一構造）
typedef WeatherCache = WeatherInfo;
