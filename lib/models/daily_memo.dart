import 'flowdo_calendar.dart';

/// 日付キー（YYYY-MM-DD）
String dailyMemoStorageKey(DateTime day) {
  final normalized = dateOnly(day);
  final month = normalized.month.toString().padLeft(2, '0');
  final dayOfMonth = normalized.day.toString().padLeft(2, '0');
  return '${normalized.year}-$month-$dayOfMonth';
}
