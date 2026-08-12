import 'package:holiday_jp/holiday_jp.dart' as holiday_jp;

/// 日本の祝日かどうかを判定する（holiday_jp 利用）
bool isJapaneseHoliday(DateTime date) {
  return holiday_jp.isHoliday(
    DateTime(date.year, date.month, date.day),
  );
}
