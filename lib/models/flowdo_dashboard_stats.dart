import 'flowdo_calendar.dart';
import 'task.dart';
import '../screens/today_page.dart';

/// ダッシュボード用の天気スナップショット（将来 API 連携予定・現状はダミー）
class DashboardWeatherSnapshot {
  const DashboardWeatherSnapshot({
    this.locationLabel = '現在地',
    this.temperatureCelsius = 31,
    this.precipitationPercent = 40,
  });

  final String locationLabel;
  final int temperatureCelsius;
  final int precipitationPercent;

  static const dummy = DashboardWeatherSnapshot();
}

/// 今月完了したタスク数
int monthlyCompletedTaskCount(
  List<Task> tasks, {
  DateTime? referenceNow,
}) {
  final now = referenceNow ?? DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final nextMonthStart = DateTime(now.year, now.month + 1, 1);

  return tasks.where((task) {
    if (!task.isCompleted) return false;
    final completedAt = task.completedAt;
    if (completedAt == null) return false;
    return !completedAt.isBefore(monthStart) &&
        completedAt.isBefore(nextMonthStart);
  }).length;
}

/// AI コメント（ダミー）
String dashboardAiCommentDummy(String? leadingCategoryName) {
  if (leadingCategoryName == null || leadingCategoryName.isEmpty) {
    return '今日も無理せず進めましょう。';
  }

  return '今日は$leadingCategoryNameタスクが多めです。\n午前中に進めると効率的です。';
}

/// ダッシュボード統計のまとめ
class FlowDoDashboardStats {
  const FlowDoDashboardStats({
    required this.achievement,
    required this.monthlyCompletedCount,
    required this.weather,
    required this.aiComment,
  });

  final TodayAchievementStats achievement;
  final int monthlyCompletedCount;
  final DashboardWeatherSnapshot weather;
  final String aiComment;

  factory FlowDoDashboardStats.fromTasks({
    required List<Task> tasks,
    String? leadingCategoryName,
    DateTime? referenceToday,
    DashboardWeatherSnapshot weather = DashboardWeatherSnapshot.dummy,
  }) {
    final today = referenceToday ?? DateTime.now();
    return FlowDoDashboardStats(
      achievement: todayAchievementStats(
        tasks: tasks,
        referenceToday: today,
      ),
      monthlyCompletedCount: monthlyCompletedTaskCount(
        tasks,
        referenceNow: today,
      ),
      weather: weather,
      aiComment: dashboardAiCommentDummy(leadingCategoryName),
    );
  }
}
