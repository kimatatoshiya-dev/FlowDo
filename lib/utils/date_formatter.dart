import 'package:flutter/material.dart';

/// 期限チップの緊急度
enum DueDateUrgency {
  overdue,
  today,
  tomorrow,
  soon,
  upcoming,
}

/// タスクカードの期限表示用データ
class DueDateChipDisplay {
  const DueDateChipDisplay({
    required this.headline,
    required this.subDateLabel,
    this.timeLabel,
    required this.urgency,
  });

  final String headline;
  final String subDateLabel;
  final String? timeLabel;
  final DueDateUrgency urgency;

  String get tooltipLabel {
    final buffer = StringBuffer(headline)
      ..writeln()
      ..write(subDateLabel);
    if (timeLabel != null) {
      buffer
        ..writeln()
        ..write(timeLabel);
    }
    return buffer.toString();
  }

  /// タスクカード用の1行期限表示（例: 🔥 今日　8/13(木)　🕒12:00）
  String get inlineLabel {
    final parts = <String>[headline, subDateLabel];
    if (timeLabel != null) {
      parts.add(timeLabel!);
    }
    return parts.join('　');
  }
}

/// 日付の表示フォーマット
class DateFormatter {
  DateFormatter._();

  static const _weekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];

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

  /// タスクカード用の日付サブ表示（例: 8/17(月)）
  static String formatDueDateWithWeekday(DateTime date, {DateTime? reference}) {
    final weekday = _weekdayLabels[date.weekday - 1];
    final ref = reference ?? DateTime.now();
    final m = date.month;
    final d = date.day;
    if (date.year == ref.year) {
      return '$m/$d($weekday)';
    }
    return '${date.year}/$m/$d($weekday)';
  }

  static int daysUntilDue(DateTime dueDate, {DateTime? reference}) {
    final ref = _dateOnly(reference ?? DateTime.now());
    final due = _dateOnly(dueDate);
    return due.difference(ref).inDays;
  }

  /// タスクカードの期限チップ表示を組み立てる
  static DueDateChipDisplay buildTaskDueChipDisplay({
    required DateTime dueDate,
    TimeOfDay? reminderTime,
    DateTime? reference,
  }) {
    final ref = reference ?? DateTime.now();
    final days = daysUntilDue(dueDate, reference: ref);
    final subDateLabel = formatDueDateWithWeekday(dueDate, reference: ref);
    final timeLabel =
        reminderTime != null ? formatReminderTimeChip(reminderTime) : null;

    final String headline;
    final DueDateUrgency urgency;

    if (days < 0) {
      headline = '🗓️ 期限切れ';
      urgency = DueDateUrgency.overdue;
    } else if (days == 0) {
      headline = '🗓️ 今日';
      urgency = DueDateUrgency.today;
    } else if (days == 1) {
      headline = '🗓️ 明日';
      urgency = DueDateUrgency.tomorrow;
    } else {
      headline = '🗓️ あと$days日';
      urgency = days <= 3 ? DueDateUrgency.soon : DueDateUrgency.upcoming;
    }

    return DueDateChipDisplay(
      headline: headline,
      subDateLabel: subDateLabel,
      timeLabel: timeLabel,
      urgency: urgency,
    );
  }

  static Color dueDateChipForeground(
    DueDateUrgency urgency, {
    required ColorScheme colorScheme,
    required Color secondaryLabel,
    bool muted = false,
  }) {
    final color = switch (urgency) {
      DueDateUrgency.overdue => colorScheme.error,
      DueDateUrgency.today => const Color(0xFFFF9500),
      DueDateUrgency.tomorrow => const Color(0xFF007AFF),
      DueDateUrgency.soon => const Color(0xFFFF9500),
      DueDateUrgency.upcoming => secondaryLabel,
    };
    return muted ? color.withValues(alpha: 0.65) : color;
  }

  static Color dueDateChipBackground(
    DueDateUrgency urgency, {
    required ColorScheme colorScheme,
    required Color secondaryLabel,
    bool muted = false,
  }) {
    final strongAlpha = muted ? 0.07 : 0.09;
    final subtleAlpha = muted ? 0.04 : 0.06;
    return switch (urgency) {
      DueDateUrgency.overdue =>
        colorScheme.error.withValues(alpha: strongAlpha),
      DueDateUrgency.today =>
        const Color(0xFFFF9500).withValues(alpha: strongAlpha),
      DueDateUrgency.tomorrow =>
        const Color(0xFF007AFF).withValues(alpha: strongAlpha),
      DueDateUrgency.soon =>
        const Color(0xFFFF9500).withValues(alpha: subtleAlpha),
      DueDateUrgency.upcoming =>
        secondaryLabel.withValues(alpha: subtleAlpha),
    };
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
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

  /// 期限 BottomSheet 用の時間表示（例: 🕘 09:00）
  static String formatReminderTimeSheet(TimeOfDay time) {
    final emoji = _clockEmojis[time.hour % 12];
    return '$emoji ${formatReminderTime(time)}';
  }
}
