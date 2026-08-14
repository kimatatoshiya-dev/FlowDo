import 'package:geolocator/geolocator.dart';

/// 天気取得用の位置情報
class WeatherCoordinates {
  const WeatherCoordinates({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

/// 現在地を取得する（権限未許可時は null）
Future<WeatherCoordinates?> resolveCurrentWeatherLocation() async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return null;

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return null;
  }

  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.low,
      timeLimit: Duration(seconds: 10),
    ),
  );

  return WeatherCoordinates(
    latitude: position.latitude,
    longitude: position.longitude,
  );
}
