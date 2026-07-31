/// SharedPreferences から復元した JSON の型ゆらぎを安全に読み取る
class JsonRead {
  JsonRead._();

  static String? string(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static int? integer(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static bool boolean(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    return fallback;
  }
}
