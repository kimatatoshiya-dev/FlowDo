import 'flowdo_calendar.dart';
import 'task.dart';
import 'task_repeat_type.dart';
import '../screens/today_page.dart';

/// ダッシュボード用の天気スナップショット（将来 API 連携予定・現状はダミー）
class DashboardWeatherSnapshot {
  const DashboardWeatherSnapshot({
    this.locationLabel = '東京',
    this.temperatureCelsius = 31,
    this.precipitationPercent = 10,
    this.weatherIconEmoji = '☀️',
  });

  final String locationLabel;
  final int temperatureCelsius;
  final int precipitationPercent;
  final String weatherIconEmoji;

  static const dummy = DashboardWeatherSnapshot();
}

/// 未完了タスクのサマリー件数
class DashboardTaskSummaryCounts {
  const DashboardTaskSummaryCounts({
    required this.dueTodayCount,
    required this.importantCount,
    required this.dueWithin7DaysCount,
  });

  final int dueTodayCount;
  final int importantCount;
  final int dueWithin7DaysCount;
}

/// ルーティンの完了状況
class DashboardRoutineStats {
  const DashboardRoutineStats({
    required this.completedCount,
    required this.totalCount,
  });

  final int completedCount;
  final int totalCount;

  String get displayValue => '$completedCount / $totalCount';
}

DashboardTaskSummaryCounts dashboardTaskSummaryCounts(
  List<Task> tasks, {
  DateTime? referenceToday,
}) {
  final today = dateOnly(referenceToday ?? DateTime.now());
  final weekEnd = today.add(const Duration(days: 7));
  final incomplete = tasks.where((task) => !task.isCompleted);

  var importantCount = 0;
  var dueTodayCount = 0;
  var dueWithin7DaysCount = 0;

  for (final task in incomplete) {
    if (task.isFavorite) importantCount++;
    if (task.dueDate == null) continue;

    final due = dateOnly(task.dueDate!);
    if (isSameDay(due, today)) {
      dueTodayCount++;
    }
    if (!due.isBefore(today) && !due.isAfter(weekEnd)) {
      dueWithin7DaysCount++;
    }
  }

  return DashboardTaskSummaryCounts(
    dueTodayCount: dueTodayCount,
    importantCount: importantCount,
    dueWithin7DaysCount: dueWithin7DaysCount,
  );
}

DashboardRoutineStats dashboardRoutineStats(
  List<Task> tasks, {
  DateTime? referenceToday,
}) {
  final today = dateOnly(referenceToday ?? DateTime.now());
  final routines = todayRoutineTasks(tasks: tasks);
  var completedCount = 0;

  for (final task in routines) {
    if (DailyRoutineLogic.isCompletedToday(task, today)) {
      completedCount++;
    }
  }

  return DashboardRoutineStats(
    completedCount: completedCount,
    totalCount: routines.length,
  );
}

/// ダッシュボード統計のまとめ
class FlowDoDashboardStats {
  const FlowDoDashboardStats({
    required this.counts,
    required this.routine,
    required this.achievement,
    required this.weather,
    required this.streakDays,
  });

  final DashboardTaskSummaryCounts counts;
  final DashboardRoutineStats routine;
  final TodayAchievementStats achievement;
  final DashboardWeatherSnapshot weather;

  /// 将来 HealthKit 等と連携予定・現状はダミー
  final int streakDays;

  factory FlowDoDashboardStats.fromTasks({
    required List<Task> tasks,
    DateTime? referenceToday,
    DashboardWeatherSnapshot weather = DashboardWeatherSnapshot.dummy,
    int streakDays = 12,
  }) {
    final today = referenceToday ?? DateTime.now();
    return FlowDoDashboardStats(
      counts: dashboardTaskSummaryCounts(
        tasks,
        referenceToday: today,
      ),
      routine: dashboardRoutineStats(
        tasks,
        referenceToday: today,
      ),
      achievement: todayAchievementStats(
        tasks: tasks,
        referenceToday: today,
      ),
      weather: weather,
      streakDays: streakDays,
    );
  }
}
