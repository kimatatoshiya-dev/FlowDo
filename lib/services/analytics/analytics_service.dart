import 'package:flutter/material.dart';

export 'analytics_events.dart';
export 'firebase_analytics_service.dart';
export 'noop_analytics_service.dart';

/// 利用状況分析の抽象インターフェース（Firebase / Amplitude 等に差し替え可能）
abstract class AnalyticsService {
  Future<void> logAppOpen();

  Future<void> logScreenView(String screenName);

  Future<void> logFirstLaunch();

  Future<void> logSessionDuration({required int durationSeconds});

  Future<void> logCaptureUsed({required int taskCount});

  Future<void> logBulkInputCount({required int count});

  Future<void> logTaskCreated({required int taskCount});

  Future<void> logTaskCompleted();

  Future<void> logTaskDeleted();

  Future<void> logCategoryChanged({required String context});

  Future<void> logPriorityChanged({
    required String context,
    required int stars,
  });

  Future<void> logDeadlineSet({required int daysUntilDue});

  Future<void> logAiSortStarted({required int taskCount});

  Future<void> logAiSortCompleted({required int taskCount});

  Future<void> logSoundEnabled();

  Future<void> logSoundDisabled();

  Future<void> logHapticEnabled();

  Future<void> logHapticDisabled();

  Future<void> logThemeChanged(ThemeMode mode);
}
