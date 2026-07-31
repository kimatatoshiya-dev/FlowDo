import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'analytics_service.dart';

/// Firebase Analytics 実装
class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService(this._analytics);

  final FirebaseAnalytics _analytics;

  @override
  Future<void> logAppOpen() async {
    _debugLog('app_open');
    await _analytics.logAppOpen();
  }

  @override
  Future<void> logScreenView(String screenName) async {
    _debugLog('screen_view', {'screen_name': screenName});
    await _analytics.logScreenView(screenName: screenName);
  }

  @override
  Future<void> logFirstLaunch() => _log(AnalyticsEvent.firstLaunch);

  @override
  Future<void> logSessionDuration({required int durationSeconds}) {
    return _log(
      AnalyticsEvent.sessionDuration,
      {AnalyticsParam.durationSeconds: durationSeconds},
    );
  }

  @override
  Future<void> logCaptureUsed({required int taskCount}) {
    return _log(
      AnalyticsEvent.captureUsed,
      {AnalyticsParam.taskCount: taskCount},
    );
  }

  @override
  Future<void> logBulkInputCount({required int count}) {
    return _log(
      AnalyticsEvent.bulkInputCount,
      {AnalyticsParam.count: count},
    );
  }

  @override
  Future<void> logTaskCreated({required int taskCount}) {
    return _log(
      AnalyticsEvent.taskCreated,
      {AnalyticsParam.taskCount: taskCount},
    );
  }

  @override
  Future<void> logTaskCompleted() => _log(AnalyticsEvent.taskCompleted);

  @override
  Future<void> logTaskDeleted() => _log(AnalyticsEvent.taskDeleted);

  @override
  Future<void> logCategoryChanged({required String context}) {
    return _log(
      AnalyticsEvent.categoryChanged,
      {AnalyticsParam.context: context},
    );
  }

  @override
  Future<void> logPriorityChanged({
    required String context,
    required int stars,
  }) {
    return _log(
      AnalyticsEvent.priorityChanged,
      {
        AnalyticsParam.context: context,
        AnalyticsParam.stars: stars,
      },
    );
  }

  @override
  Future<void> logDeadlineSet({required int daysUntilDue}) {
    return _log(
      AnalyticsEvent.deadlineSet,
      {AnalyticsParam.daysUntilDue: daysUntilDue},
    );
  }

  @override
  Future<void> logAiSortStarted({required int taskCount}) {
    return _log(
      AnalyticsEvent.aiSortStarted,
      {AnalyticsParam.taskCount: taskCount},
    );
  }

  @override
  Future<void> logAiSortCompleted({required int taskCount}) {
    return _log(
      AnalyticsEvent.aiSortCompleted,
      {AnalyticsParam.taskCount: taskCount},
    );
  }

  @override
  Future<void> logSoundEnabled() => _log(AnalyticsEvent.soundEnabled);

  @override
  Future<void> logSoundDisabled() => _log(AnalyticsEvent.soundDisabled);

  @override
  Future<void> logHapticEnabled() => _log(AnalyticsEvent.hapticEnabled);

  @override
  Future<void> logHapticDisabled() => _log(AnalyticsEvent.hapticDisabled);

  @override
  Future<void> logThemeChanged(ThemeMode mode) {
    return _log(
      AnalyticsEvent.themeChanged,
      {AnalyticsParam.theme: _themeValue(mode)},
    );
  }

  Future<void> _log(String name, [Map<String, Object>? parameters]) async {
    _debugLog(name, parameters);
    await _analytics.logEvent(name: name, parameters: parameters);
  }

  void _debugLog(String name, [Map<String, Object>? parameters]) {
    if (!kDebugMode) return;
    final suffix = parameters == null || parameters.isEmpty
        ? ''
        : ' ${parameters.entries.map((e) => '${e.key}=${e.value}').join(', ')}';
    debugPrint('Analytics: $name$suffix');
  }

  static String _themeValue(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }
}
