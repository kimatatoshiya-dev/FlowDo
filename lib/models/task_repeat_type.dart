import 'flowdo_calendar.dart';
import 'task.dart';

/// タスクの繰り返し種別
enum TaskRepeatType {
  none,
  daily,
  weekly,
  monthly,
  yearly,
}

extension TaskRepeatTypeLabels on TaskRepeatType {
  String get label => switch (this) {
        TaskRepeatType.none => 'なし',
        TaskRepeatType.daily => '毎日',
        TaskRepeatType.weekly => '毎週',
        TaskRepeatType.monthly => '毎月',
        TaskRepeatType.yearly => '毎年',
      };

  static TaskRepeatType fromStorage(String? value) {
    if (value == null || value.isEmpty) return TaskRepeatType.none;
    return TaskRepeatType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => TaskRepeatType.none,
    );
  }
}

/// 繰り返しタスクか
bool taskHasRepeatSchedule(Task task) => task.repeatType != TaskRepeatType.none;

/// 毎日ルーティンの完了・リセット判定
abstract final class DailyRoutineLogic {
  /// 当日完了として表示すべきか
  static bool isCompletedToday(Task task, DateTime referenceNow) {
    if (task.repeatType != TaskRepeatType.daily) {
      return task.isCompleted;
    }
    if (!task.isCompleted || task.completedAt == null) return false;
    return isSameDay(dateOnly(task.completedAt!), dateOnly(referenceNow));
  }

  /// 前日以前に完了した daily タスクを未完了へ戻す
  static bool resetExpiredDailyTasks(
    List<Task> tasks, {
    DateTime? referenceNow,
  }) {
    final today = dateOnly(referenceNow ?? DateTime.now());
    var changed = false;

    for (final task in tasks) {
      if (task.repeatType != TaskRepeatType.daily) continue;
      if (!task.isCompleted || task.completedAt == null) continue;
      if (isSameDay(dateOnly(task.completedAt!), today)) continue;
      task
        ..isCompleted = false
        ..completedAt = null;
      changed = true;
    }

    return changed;
  }
}

/// Today 画面 — 繰り返しタスク（daily / weekly / monthly / yearly）
List<Task> todayRoutineTasks({
  required List<Task> tasks,
}) {
  final routines =
      tasks.where((task) => taskHasRepeatSchedule(task)).toList();
  routines.sort((a, b) => a.title.compareTo(b.title));
  return routines;
}
