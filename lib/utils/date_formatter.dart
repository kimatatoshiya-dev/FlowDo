import 'package:flutter/material.dart';

/// 日付の表示フォーマット
class DateFormatter {
  DateFormatter._();

  /// 期限未設定時の表示ラベル
  static const noDueDateLabel = '期限なし';

  /// 時間未設定時の表示ラベル
  static const noReminderTimeLabel = '時間なし';

  static String format(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}/$m/$d';
  }

  /// タスク一覧の期限表示（今年は M/D、それ以外は YYYY/M/D）
  static String formatDueDate(DateTime date, {DateTime? reference}) {
    final ref = reference ?? DateTime.now();
    final m = date.month;
    final d = date.day;
    if (date.year == ref.year) {
      return '$m/$d';
    }
    return '${date.year}/$m/$d';
  }

  static String formatDateTime(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '${format(date)} $h:$min';
  }

  static String formatReminderTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String formatReminderTimeChip(TimeOfDay time) {
    return '🕒${formatReminderTime(time)}';
  }

  static String formatDueDateWithTimeChip(DateTime date, TimeOfDay time) {
    return '📅 ${formatDueDate(date)}\n${formatReminderTimeChip(time)}';
  }

  static const _clockEmojis = [
    '🕛',
    '🕐',
    '🕑',
    '🕒',
    '🕓',
    '🕔',
    '🕕',
    '🕖',
    '🕗',
    '🕘',
    '🕙',
    '🕚',
  ];

  static String formatCalendarTaskTime(TimeOfDay time) {
    final emoji = _clockEmojis[time.hour % 12];
    return '$emoji${formatReminderTime(time)}';
  }
}
