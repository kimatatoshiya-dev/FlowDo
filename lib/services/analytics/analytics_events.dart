/// Analytics 画面名（個人情報を含まない識別子のみ）
abstract final class AnalyticsScreen {
  static const home = 'home_screen';
  static const settings = 'settings_screen';
}

/// タスク操作の文脈（カテゴリー名・タスク内容は送らない）
abstract final class AnalyticsContext {
  static const inbox = 'inbox';
  static const list = 'list';
}

/// Firebase カスタムイベント名（snake_case で統一）
abstract final class AnalyticsEvent {
  // ライフサイクル
  static const firstLaunch = 'first_launch';
  static const sessionDuration = 'session_duration';

  // タスク入力・整理
  static const captureUsed = 'capture_used';
  static const bulkInputCount = 'bulk_input_count';
  static const taskCreated = 'task_created';
  static const taskCompleted = 'task_completed';
  static const taskDeleted = 'task_deleted';
  static const categoryChanged = 'category_changed';
  static const priorityChanged = 'priority_changed';
  static const deadlineSet = 'deadline_set';

  // AI 整理
  static const aiSortStarted = 'ai_sort_started';
  static const aiSortCompleted = 'ai_sort_completed';

  // 設定
  static const soundEnabled = 'sound_enabled';
  static const soundDisabled = 'sound_disabled';
  static const hapticEnabled = 'haptic_enabled';
  static const hapticDisabled = 'haptic_disabled';
  static const themeChanged = 'theme_changed';
}

/// イベントパラメータキー（Firebase 制限: 25 文字以内・個人情報禁止）
abstract final class AnalyticsParam {
  static const count = 'count';
  static const taskCount = 'task_count';
  static const durationSeconds = 'duration_seconds';
  static const context = 'context';
  static const stars = 'stars';
  static const daysUntilDue = 'days_until_due';
  static const theme = 'theme';
}
