import 'package:flutter/material.dart';

import 'analytics_service.dart';

/// テスト・Firebase 未初期化時の no-op 実装
class NoOpAnalyticsService implements AnalyticsService {
  const NoOpAnalyticsService();

  @override
  Future<void> logAppOpen() async {}

  @override
  Future<void> logScreenView(String screenName) async {}

  @override
  Future<void> logFirstLaunch() async {}

  @override
  Future<void> logSessionDuration({required int durationSeconds}) async {}

  @override
  Future<void> logCaptureUsed({required int taskCount}) async {}

  @override
  Future<void> logBulkInputCount({required int count}) async {}

  @override
  Future<void> logTaskCreated({required int taskCount}) async {}

  @override
  Future<void> logTaskCompleted() async {}

  @override
  Future<void> logTaskDeleted() async {}

  @override
  Future<void> logCategoryChanged({required String context}) async {}

  @override
  Future<void> logPriorityChanged({
    required String context,
    required int stars,
  }) async {}

  @override
  Future<void> logDeadlineSet({required int daysUntilDue}) async {}

  @override
  Future<void> logAiSortStarted({required int taskCount}) async {}

  @override
  Future<void> logAiSortCompleted({required int taskCount}) async {}

  @override
  Future<void> logSoundEnabled() async {}

  @override
  Future<void> logSoundDisabled() async {}

  @override
  Future<void> logHapticEnabled() async {}

  @override
  Future<void> logHapticDisabled() async {}

  @override
  Future<void> logThemeChanged(ThemeMode mode) async {}
}
