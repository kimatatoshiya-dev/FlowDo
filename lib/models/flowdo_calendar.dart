import 'package:flutter/material.dart';

import '../utils/japanese_holidays.dart';
import 'category_item.dart';
import 'task.dart';

/// カレンダー上のタスク種別
enum FlowDoCalendarTaskKind {
  important,
  dueToday,
  scheduled,
}

/// カレンダー日付 BottomSheet 用エントリ
class FlowDoCalendarTaskEntry {
  const FlowDoCalendarTaskEntry({
    required this.taskId,
    required this.title,
    required this.kind,
    this.reminderTime,
    this.dueDate,
    this.categoryColorValue = 0xFF8E8E93,
  });

  final int taskId;
  final String title;
  final FlowDoCalendarTaskKind kind;
  final TimeOfDay? reminderTime;
  final DateTime? dueDate;
  final int categoryColorValue;
}

/// BottomSheet 上部サマリー（表示中タスクの種別件数）
class CalendarDaySheetSummary {
  const CalendarDaySheetSummary({
    required this.dueTodayCount,
    required this.importantCount,
    required this.scheduledCount,
  });

  final int dueTodayCount;
  final int importantCount;
  final int scheduledCount;

  bool get hasAny =>
      dueTodayCount > 0 || importantCount > 0 || scheduledCount > 0;

  factory CalendarDaySheetSummary.fromEntries(
    List<FlowDoCalendarTaskEntry> entries,
  ) {
    var dueTodayCount = 0;
    var importantCount = 0;
    var scheduledCount = 0;

    for (final entry in entries) {
      switch (entry.kind) {
        case FlowDoCalendarTaskKind.important:
          importantCount++;
        case FlowDoCalendarTaskKind.dueToday:
          dueTodayCount++;
        case FlowDoCalendarTaskKind.scheduled:
          scheduledCount++;
      }
    }

    return CalendarDaySheetSummary(
      dueTodayCount: dueTodayCount,
      importantCount: importantCount,
      scheduledCount: scheduledCount,
    );
  }
}

/// カレンダー上部の件数サマリー
class FlowDoCalendarSummary {
  const FlowDoCalendarSummary({
    required this.importantCount,
    required this.dueTodayCount,
    required this.dueWithin7DaysCount,
    required this.dueThisMonthCount,
  });

  final int importantCount;
  final int dueTodayCount;
  final int dueWithin7DaysCount;
  final int dueThisMonthCount;
}

/// 日付セルに表示するマーカー
class FlowDoCalendarDayMarkers {
  const FlowDoCalendarDayMarkers({
    this.showImportant = false,
    this.showDueToday = false,
    this.showScheduled = false,
  });

  final bool showImportant;
  final bool showDueToday;
  final bool showScheduled;

  bool get hasAny =>
      showImportant || showDueToday || showScheduled;
}

/// 今月カレンダー用データ
class FlowDoCalendarMonthData {
  FlowDoCalendarMonthData({
    required this.month,
    required this.summary,
    required Map<DateTime, FlowDoCalendarDayMarkers> dayMarkers,
    DateTime? today,
  })  : today = dateOnly(today ?? DateTime.now()),
        dayMarkers = Map.unmodifiable(dayMarkers);

  final DateTime month;
  final FlowDoCalendarSummary summary;
  final Map<DateTime, FlowDoCalendarDayMarkers> dayMarkers;
  final DateTime today;

  FlowDoCalendarDayMarkers markersFor(DateTime day) {
    return dayMarkers[dateOnly(day)] ?? const FlowDoCalendarDayMarkers();
  }

  int get year => month.year;
  int get monthNumber => month.month;
  int get daysInMonth => DateTime(year, monthNumber + 1, 0).day;
  int get firstWeekday => DateTime(year, monthNumber, 1).weekday % 7;
}

DateTime dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// 今月カレンダーデータを組み立てる
FlowDoCalendarMonthData buildFlowDoCalendarMonth({
  required List<Task> tasks,
  DateTime? month,
  DateTime? today,
}) {
  final referenceToday = dateOnly(today ?? DateTime.now());
  final targetMonth = dateOnly(month ?? referenceToday);
  final monthStart = DateTime(targetMonth.year, targetMonth.month, 1);
  final monthEnd = DateTime(targetMonth.year, targetMonth.month + 1, 0);

  final incomplete = tasks.where((task) => !task.isCompleted).toList();

  var importantCount = 0;
  var dueTodayCount = 0;
  var dueWithin7DaysCount = 0;
  var dueThisMonthCount = 0;
  final weekEnd = referenceToday.add(const Duration(days: 7));

  for (final task in incomplete) {
    if (task.isFavorite) importantCount++;
    if (task.dueDate != null) {
      final due = dateOnly(task.dueDate!);
      if (isSameDay(due, referenceToday)) {
        dueTodayCount++;
      }
      if (!due.isBefore(referenceToday) && !due.isAfter(weekEnd)) {
        dueWithin7DaysCount++;
      }
      if (!due.isBefore(monthStart) && !due.isAfter(monthEnd)) {
        dueThisMonthCount++;
      }
    }
  }

  final markers = <DateTime, FlowDoCalendarDayMarkers>{};

  void mergeMarker(DateTime day, FlowDoCalendarDayMarkers patch) {
    final key = dateOnly(day);
    final current = markers[key] ?? const FlowDoCalendarDayMarkers();
    markers[key] = FlowDoCalendarDayMarkers(
      showImportant: current.showImportant || patch.showImportant,
      showDueToday: current.showDueToday || patch.showDueToday,
      showScheduled: current.showScheduled || patch.showScheduled,
    );
  }

  for (final task in incomplete) {
    if (task.isFavorite && task.dueDate == null) {
      mergeMarker(
        referenceToday,
        const FlowDoCalendarDayMarkers(showImportant: true),
      );
      continue;
    }

    if (task.dueDate == null) continue;

    final due = dateOnly(task.dueDate!);
    if (due.isBefore(monthStart) || due.isAfter(monthEnd)) continue;

    final isToday = isSameDay(due, referenceToday);
    mergeMarker(
      due,
      FlowDoCalendarDayMarkers(
        showImportant: task.isFavorite,
        showDueToday: isToday,
        showScheduled: true,
      ),
    );
  }

  return FlowDoCalendarMonthData(
    month: monthStart,
    summary: FlowDoCalendarSummary(
      importantCount: importantCount,
      dueTodayCount: dueTodayCount,
      dueWithin7DaysCount: dueWithin7DaysCount,
      dueThisMonthCount: dueThisMonthCount,
    ),
    dayMarkers: markers,
    today: referenceToday,
  );
}

/// 指定日のセルにタスクが属するか（カレンダーマーカーと同じ基準）
bool taskBelongsToCalendarDay({
  required Task task,
  required DateTime day,
  required DateTime today,
}) {
  if (task.isCompleted) return false;

  final targetDay = dateOnly(day);
  final referenceToday = dateOnly(today);

  if (task.isFavorite && task.dueDate == null) {
    return isSameDay(targetDay, referenceToday);
  }

  if (task.dueDate == null) return false;

  return isSameDay(dateOnly(task.dueDate!), targetDay);
}

/// 指定日 BottomSheet 用のタスク種別（マーカー表示と同じ基準）
FlowDoCalendarTaskKind? calendarTaskKindForDay({
  required Task task,
  required DateTime day,
  required DateTime today,
}) {
  if (!taskBelongsToCalendarDay(task: task, day: day, today: today)) {
    return null;
  }

  final targetDay = dateOnly(day);
  final referenceToday = dateOnly(today);

  if (task.isFavorite &&
      (task.dueDate == null || isSameDay(dateOnly(task.dueDate!), targetDay))) {
    return FlowDoCalendarTaskKind.important;
  }

  if (isSameDay(targetDay, referenceToday)) {
    return FlowDoCalendarTaskKind.dueToday;
  }

  return FlowDoCalendarTaskKind.scheduled;
}

/// 指定日の BottomSheet 用タスク一覧
List<FlowDoCalendarTaskEntry> calendarTasksForDay({
  required List<Task> tasks,
  required DateTime day,
  DateTime? today,
  List<CategoryItem> categories = const [],
}) {
  final referenceToday = dateOnly(today ?? DateTime.now());
  final entries = <FlowDoCalendarTaskEntry>[];

  for (final task in tasks) {
    final kind = calendarTaskKindForDay(
      task: task,
      day: day,
      today: referenceToday,
    );
    if (kind == null) continue;

    final category = resolveCategory(task.categoryId, categories);

    entries.add(
      FlowDoCalendarTaskEntry(
        taskId: task.id,
        title: task.title,
        kind: kind,
        reminderTime: task.reminderTime,
        dueDate: task.dueDate == null ? null : dateOnly(task.dueDate!),
        categoryColorValue: category.colorValue,
      ),
    );
  }

  int compareTimeOfDay(TimeOfDay a, TimeOfDay b) {
    final hourCompare = a.hour.compareTo(b.hour);
    if (hourCompare != 0) return hourCompare;
    return a.minute.compareTo(b.minute);
  }

  int kindOrder(FlowDoCalendarTaskKind value) => switch (value) {
        FlowDoCalendarTaskKind.important => 0,
        FlowDoCalendarTaskKind.dueToday => 1,
        FlowDoCalendarTaskKind.scheduled => 2,
      };

  entries.sort((a, b) {
    final kindCompare = kindOrder(a.kind).compareTo(kindOrder(b.kind));
    if (kindCompare != 0) return kindCompare;

    final aHasTime = a.reminderTime != null;
    final bHasTime = b.reminderTime != null;
    if (aHasTime && bHasTime) {
      final timeCompare =
          compareTimeOfDay(a.reminderTime!, b.reminderTime!);
      if (timeCompare != 0) return timeCompare;
    } else if (aHasTime != bHasTime) {
      return aHasTime ? -1 : 1;
    }

    return a.title.compareTo(b.title);
  });

  return entries;
}

String formatCalendarMonthTitle(DateTime month) {
  return '${month.year}年${month.month}月';
}

/// カレンダー曜日ラベルの色（日=赤、土=青、平日=標準）
Color calendarWeekdayLabelColor({
  required int weekdayIndex,
  required Color standardColor,
}) {
  return switch (weekdayIndex) {
    0 => calendarSundayColor,
    6 => calendarSaturdayColor,
    _ => standardColor,
  };
}

/// カレンダー日付数字の色（今日は青丸内の白文字を優先）
Color calendarDayNumberColor({
  required DateTime day,
  required bool isToday,
  required Color standardColor,
}) {
  if (isToday) return Colors.white;

  if (isJapaneseHoliday(day) || day.weekday == DateTime.sunday) {
    return calendarSundayColor;
  }
  if (day.weekday == DateTime.saturday) {
    return calendarSaturdayColor;
  }
  return standardColor;
}

const calendarSundayColor = Color(0xFFE53935);
const calendarSaturdayColor = Color(0xFF1565C0);

String formatCalendarDayTitle(DateTime day) {
  const labels = ['月', '火', '水', '木', '金', '土', '日'];
  return '${day.month}月${day.day}日（${labels[day.weekday - 1]}）';
}

String calendarTaskKindEmoji(FlowDoCalendarTaskKind kind) {
  return switch (kind) {
    FlowDoCalendarTaskKind.important => '📌',
    FlowDoCalendarTaskKind.dueToday => '🔥',
    FlowDoCalendarTaskKind.scheduled => '🗓️',
  };
}
