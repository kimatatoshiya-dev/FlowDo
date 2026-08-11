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
  });

  final int taskId;
  final String title;
  final FlowDoCalendarTaskKind kind;
}

/// カレンダー上部の件数サマリー
class FlowDoCalendarSummary {
  const FlowDoCalendarSummary({
    required this.importantCount,
    required this.dueTodayCount,
    required this.dueThisMonthCount,
  });

  final int importantCount;
  final int dueTodayCount;
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
  var dueThisMonthCount = 0;

  for (final task in incomplete) {
    if (task.isFavorite) importantCount++;
    if (task.dueDate != null &&
        isSameDay(dateOnly(task.dueDate!), referenceToday)) {
      dueTodayCount++;
    }
    if (task.dueDate != null) {
      final due = dateOnly(task.dueDate!);
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
      dueThisMonthCount: dueThisMonthCount,
    ),
    dayMarkers: markers,
    today: referenceToday,
  );
}

/// 指定日の BottomSheet 用タスク一覧
List<FlowDoCalendarTaskEntry> calendarTasksForDay({
  required List<Task> tasks,
  required DateTime day,
  DateTime? today,
}) {
  final targetDay = dateOnly(day);
  final referenceToday = dateOnly(today ?? DateTime.now());
  final entries = <FlowDoCalendarTaskEntry>[];

  for (final task in tasks) {
    if (task.isCompleted) continue;

    FlowDoCalendarTaskKind? kind;

    if (task.isFavorite && task.dueDate == null && isSameDay(targetDay, referenceToday)) {
      kind = FlowDoCalendarTaskKind.important;
    } else if (task.dueDate != null && isSameDay(task.dueDate!, targetDay)) {
      if (task.isFavorite) {
        kind = FlowDoCalendarTaskKind.important;
      } else if (isSameDay(targetDay, referenceToday)) {
        kind = FlowDoCalendarTaskKind.dueToday;
      } else {
        kind = FlowDoCalendarTaskKind.scheduled;
      }
    }

    if (kind == null) continue;

    entries.add(
      FlowDoCalendarTaskEntry(
        taskId: task.id,
        title: task.title,
        kind: kind,
      ),
    );
  }

  int kindOrder(FlowDoCalendarTaskKind value) => switch (value) {
        FlowDoCalendarTaskKind.important => 0,
        FlowDoCalendarTaskKind.dueToday => 1,
        FlowDoCalendarTaskKind.scheduled => 2,
      };

  entries.sort((a, b) {
    final kindCompare = kindOrder(a.kind).compareTo(kindOrder(b.kind));
    if (kindCompare != 0) return kindCompare;
    return a.title.compareTo(b.title);
  });

  return entries;
}

String formatCalendarMonthTitle(DateTime month) {
  return '${month.year}年${month.month}月';
}

String formatCalendarDayTitle(DateTime day) {
  const labels = ['月', '火', '水', '木', '金', '土', '日'];
  return '${day.month}月${day.day}日（${labels[day.weekday - 1]}）';
}

String calendarTaskKindEmoji(FlowDoCalendarTaskKind kind) {
  return switch (kind) {
    FlowDoCalendarTaskKind.important => '📌',
    FlowDoCalendarTaskKind.dueToday => '🔥',
    FlowDoCalendarTaskKind.scheduled => '📅',
  };
}
