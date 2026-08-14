/// Open-Meteo WMO weather code を Dashboard 表示用絵文字へ変換
String weatherCodeToEmoji(int code) {
  if (code == 0) return '☀️';
  if (code == 1 || code == 2) return '🌤';
  if (code == 3 || code == 45 || code == 48) return '☁️';
  if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
    return '🌧';
  }
  if (code >= 95 && code <= 99) return '⛈';
  if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86)) {
    return '❄️';
  }
  return '🌤';
}
