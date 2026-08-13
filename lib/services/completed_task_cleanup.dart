import '../models/completed_task_retention.dart';
import '../models/task.dart';
import '../models/task_repeat_type.dart';

/// 完了タスクの自動整理
abstract final class CompletedTaskCleanup {
  /// 完了日時が未記録のタスクにフォールバックを設定する
  static void backfillCompletionTimestamps(List<Task> tasks) {
    for (final task in tasks) {
      if (task.isCompleted && task.completedAt == null) {
        task.completedAt = task.createdAt;
      }
    }
  }

  /// 保持期間を過ぎた完了タスクを除いたリストを返す
  static List<Task> filterExpired(
    List<Task> tasks,
    CompletedTaskRetention retention, {
    DateTime? now,
  }) {
    final days = retention.retentionDays;
    if (days == null) return List<Task>.from(tasks);

    final reference = now ?? DateTime.now();
    final cutoff = Duration(days: days);

    return tasks.where((task) {
      if (taskHasRepeatSchedule(task)) return true;
      if (!task.isCompleted) return true;
      final completedAt = task.completedAt ?? task.createdAt;
      return reference.difference(completedAt) < cutoff;
    }).toList();
  }

  /// 保持期間を過ぎた完了タスクのみを返す
  static List<Task> expiredTasks(
    List<Task> tasks,
    CompletedTaskRetention retention, {
    DateTime? now,
  }) {
    final days = retention.retentionDays;
    if (days == null) return const [];

    final reference = now ?? DateTime.now();
    final cutoff = Duration(days: days);

    return tasks.where((task) {
      if (!task.isCompleted) return false;
      final completedAt = task.completedAt ?? task.createdAt;
      return reference.difference(completedAt) >= cutoff;
    }).toList();
  }
}
