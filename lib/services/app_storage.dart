import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/category_item.dart';
import '../models/completed_task_retention.dart';
import '../models/feedback_preferences.dart';
import '../models/notification_preferences.dart';
import '../models/task.dart';
import '../debug/task_storage_log.dart';
import '../debug/task_persistence_diag.dart';

/// アプリ設定・タスク・カテゴリーの永続化
///
/// SharedPreferences が利用できない場合でも例外を外に投げず、
/// 読み込みはデフォルト値、保存は黙ってスキップする。
class AppStorage {
  AppStorage._();

  static const _tasksKey = 'flowdo_tasks';
  static const _categoriesKey = 'flowdo_categories';
  static const _lastRegistrationCategoryKey =
      'flowdo_last_registration_category_id';
  static const _themeModeKey = 'flowdo_theme_mode';
  static const _feedbackPreferencesKey = 'flowdo_feedback_preferences';
  static const _notificationPreferencesKey = 'flowdo_notification_preferences';
  static const _completedTaskRetentionKey = 'flowdo_completed_task_retention';
  static const _firstLaunchLoggedKey = 'flowdo_analytics_first_launch_logged';
  static const _inputGuidanceSeenKey = 'flowdo_input_guidance_seen';
  static const _inboxGuidanceSeenKey = 'flowdo_inbox_guidance_seen';
  static const _favoriteGuidanceSeenKey = 'flowdo_favorite_guidance_seen';
  static const _notificationPermissionPromptedKey =
      'flowdo_notification_permission_prompted';
  static const _persistVerifyReportKey = 'flowdo_persist_verify_report';
  static const _maxPrefsAttempts = 20;
  static const _prefsRetryBaseDelay = Duration(milliseconds: 100);
  static const _ensureReadyTimeout = Duration(seconds: 30);

  static SharedPreferences? _cachedPrefs;
  static bool _startupRestoreLogged = false;
  static Future<bool>? _ensureReadyFuture;

  /// SharedPreferences が利用可能か（タスクの自動保存先）
  static bool get isStorageReady => _cachedPrefs != null;

  /// テスト用: キャッシュと ensureReady の状態をリセット
  @visibleForTesting
  static void resetForTesting() {
    _cachedPrefs = null;
    _ensureReadyFuture = null;
    _startupRestoreLogged = false;
  }

  /// SharedPreferences が利用可能になるまで待つ（save/load の前提）
  static Future<bool> ensureReady({
    Duration timeout = _ensureReadyTimeout,
  }) async {
    if (_cachedPrefs != null) {
      return true;
    }

    _ensureReadyFuture ??= _ensureReadyInternal(timeout);
    try {
      return await _ensureReadyFuture!;
    } finally {
      if (_cachedPrefs == null) {
        _ensureReadyFuture = null;
      }
    }
  }

  static Future<bool> _ensureReadyInternal(Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    var attempt = 0;

    while (DateTime.now().isBefore(deadline)) {
      attempt++;
      final prefs = await _tryGetPrefs(maxAttempts: _maxPrefsAttempts);
      if (prefs != null) {
        _cachedPrefs = prefs;
        logTaskStorage('ensureReady succeeded on attempt $attempt');
        return true;
      }

      final delayMs = (_prefsRetryBaseDelay.inMilliseconds * attempt)
          .clamp(100, 2000);
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }

    logTaskStorage('ensureReady timed out after $attempt attempt(s)');
    return false;
  }

  /// iOS 実機でプラグイン初期化が遅れる場合に備え、起動時に先に温める
  static Future<bool> warmUp() => ensureReady();

  /// 起動時に保存済みタスクを読み込み、復元結果をログ出力する
  static Future<List<Task>> loadStartupTasks() async {
    final snapshot = await _loadTasksInternal(
      forceRetry: true,
      diagSource: 'loadStartupTasks',
      logStartupDiag: true,
    );
    if (!_startupRestoreLogged) {
      _startupRestoreLogged = true;
      logStartupTaskRestore(
        storageReady: snapshot.storageReady,
        tasks: snapshot.tasks,
        hadPersistedPayload: snapshot.hadPersistedPayload,
        payloadBytes: snapshot.payloadBytes,
        errorMessage: snapshot.errorMessage,
      );
    }
    return snapshot.tasks;
  }

  static Future<PersistedTaskSnapshot> readPersistedTaskSnapshot() async {
    final ready = await ensureReady();
    if (!ready) {
      return const PersistedTaskSnapshot(
        storageReady: false,
        hadPersistedPayload: false,
        taskCount: 0,
        rawJson: '',
      );
    }

    final prefs = _cachedPrefs;
    if (prefs == null) {
      return const PersistedTaskSnapshot(
        storageReady: false,
        hadPersistedPayload: false,
        taskCount: 0,
        rawJson: '',
      );
    }

    final jsonString = prefs.getString(_tasksKey);
    if (jsonString == null || jsonString.isEmpty) {
      return const PersistedTaskSnapshot(
        storageReady: true,
        hadPersistedPayload: false,
        taskCount: 0,
        rawJson: '',
      );
    }

    return PersistedTaskSnapshot(
      storageReady: true,
      hadPersistedPayload: true,
      taskCount: _countTasksInJson(jsonString),
      rawJson: jsonString,
    );
  }

  @visibleForTesting
  static Future<Map<String, dynamic>> loadPersistVerifyReport() async {
    final ready = await ensureReady();
    if (!ready) {
      return <String, dynamic>{};
    }
    final prefs = _cachedPrefs;
    final raw = prefs?.getString(_persistVerifyReportKey);
    if (raw == null || raw.isEmpty) {
      return <String, dynamic>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  @visibleForTesting
  static Future<void> savePersistVerifyReport(Map<String, dynamic> report) async {
    final ready = await ensureReady();
    if (!ready) {
      return;
    }
    final prefs = _cachedPrefs;
    if (prefs == null) {
      return;
    }
    await prefs.setString(_persistVerifyReportKey, jsonEncode(report));
  }

  /// SharedPreferences を取得する。失敗時は null（例外は投げない）
  ///
  /// [required] が true のときのみ [ensureReady] で長時間リトライする。
  /// 設定値の読み込みなどは短い試行のみ行い、未準備なら null を返す。
  static Future<SharedPreferences?> _ensurePrefs({bool required = false}) async {
    if (_cachedPrefs != null) {
      return _cachedPrefs;
    }

    if (required) {
      final ready = await ensureReady();
      return ready ? _cachedPrefs : null;
    }

    final prefs = await _tryGetPrefs(maxAttempts: 1);
    if (prefs != null) {
      _cachedPrefs = prefs;
    }
    return prefs;
  }

  static Future<SharedPreferences?> _tryGetPrefs({int? maxAttempts}) async {
    final attempts = maxAttempts ?? _maxPrefsAttempts;
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        return await SharedPreferences.getInstance();
      } catch (error, stack) {
        debugPrint(
          'SharedPreferences.getInstance failed '
          '(attempt ${attempt + 1}/$attempts): $error',
        );
        debugPrint(stack.toString());
        if (attempt < attempts - 1) {
          await Future<void>.delayed(
            _prefsRetryBaseDelay * (attempt + 1),
          );
        }
      }
    }
    return null;
  }

  static Future<List<Task>> loadTasks({
    bool forceRetry = false,
    String diagSource = 'loadTasks',
    bool logStartupDiag = false,
  }) async {
    final snapshot = await _loadTasksInternal(
      forceRetry: forceRetry,
      diagSource: diagSource,
      logStartupDiag: logStartupDiag,
    );
    return snapshot.tasks;
  }

  static Future<_TaskLoadSnapshot> _loadTasksInternal({
    bool forceRetry = false,
    String diagSource = 'internal',
    bool logStartupDiag = false,
  }) async {
    try {
      final ready = await ensureReady();
      if (!ready) {
        if (logStartupDiag) {
          logDiagStartupLoad(
            source: diagSource,
            storageReady: false,
            hadPersistedPayload: false,
            payloadBytes: null,
            taskCount: 0,
            rawJson: '',
            errorMessage: 'ensureReady timed out',
          );
        }
        return const _TaskLoadSnapshot(
          tasks: [],
          storageReady: false,
          hadPersistedPayload: false,
          errorMessage: 'SharedPreferences unavailable',
        );
      }

      final prefs = _cachedPrefs;
      if (prefs == null) {
        return const _TaskLoadSnapshot(
          tasks: [],
          storageReady: false,
          hadPersistedPayload: false,
          errorMessage: 'SharedPreferences unavailable',
        );
      }

      final jsonString = prefs.getString(_tasksKey);
      if (jsonString == null || jsonString.isEmpty) {
        if (logStartupDiag) {
          logDiagStartupLoad(
            source: diagSource,
            storageReady: true,
            hadPersistedPayload: false,
            payloadBytes: 0,
            taskCount: 0,
            rawJson: '',
          );
        }
        return _TaskLoadSnapshot(
          tasks: const [],
          storageReady: true,
          hadPersistedPayload: false,
        );
      }

      if (logStartupDiag) {
        logDiagStartupLoad(
          source: diagSource,
          storageReady: true,
          hadPersistedPayload: true,
          payloadBytes: jsonString.length,
          taskCount: _countTasksInJson(jsonString),
          rawJson: jsonString,
        );
      }

      final decoded = jsonDecode(jsonString);
      if (decoded is! List<dynamic>) {
        logTaskStorage('invalid tasks payload: expected JSON array');
        return _TaskLoadSnapshot(
          tasks: const [],
          storageReady: true,
          hadPersistedPayload: true,
          payloadBytes: jsonString.length,
          errorMessage: 'invalid JSON array',
          rawJson: jsonString,
        );
      }

      final tasks = <Task>[];
      for (final item in decoded) {
        if (item is! Map) {
          logTaskStorage('skipping invalid task entry: $item');
          continue;
        }
        try {
          tasks.add(Task.fromJson(Map<String, dynamic>.from(item)));
        } catch (error, stack) {
          logTaskStorage('skipping corrupt task entry: $error');
          debugPrint(stack.toString());
        }
      }

      Task.syncNextId(tasks);
      return _TaskLoadSnapshot(
        tasks: tasks,
        storageReady: true,
        hadPersistedPayload: true,
        payloadBytes: jsonString.length,
        rawJson: jsonString,
      );
    } catch (error, stack) {
      logTaskStorage('failed to load tasks: $error');
      debugPrint(stack.toString());
      if (logStartupDiag) {
        logDiagStartupLoad(
          source: diagSource,
          storageReady: isStorageReady,
          hadPersistedPayload: false,
          payloadBytes: null,
          taskCount: 0,
          rawJson: '',
          errorMessage: error.toString(),
        );
      }
      return _TaskLoadSnapshot(
        tasks: const [],
        storageReady: isStorageReady,
        hadPersistedPayload: false,
        errorMessage: error.toString(),
      );
    }
  }

  static int _countTasksInJson(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is List<dynamic>) {
        return decoded.length;
      }
    } catch (_) {}
    return 0;
  }

  static Future<void> saveTasks(List<Task> tasks) async {
    try {
      final ready = await ensureReady();
      if (!ready) {
        logDiagAfterSaveTasks(
          savedTaskCount: tasks.length,
          storageReady: false,
          setStringResult: null,
          verified: false,
          errorMessage: 'ensureReady timed out',
        );
        logTaskAutoSave(
          taskCount: tasks.length,
          storageReady: false,
          verified: false,
        );
        return;
      }

      final prefs = _cachedPrefs;
      if (prefs == null) {
        logDiagAfterSaveTasks(
          savedTaskCount: tasks.length,
          storageReady: false,
          setStringResult: null,
          verified: false,
          errorMessage: 'SharedPreferences unavailable after ensureReady',
        );
        return;
      }

      final jsonString = jsonEncode(tasks.map((t) => t.toJson()).toList());
      final saved = await prefs.setString(_tasksKey, jsonString);
      var verified = saved;
      if (kDebugMode) {
        final readBack = prefs.getString(_tasksKey);
        verified = saved && readBack == jsonString;
      }
      logDiagAfterSaveTasks(
        savedTaskCount: tasks.length,
        storageReady: true,
        setStringResult: saved,
        verified: verified,
      );
      logTaskAutoSave(
        taskCount: tasks.length,
        storageReady: true,
        verified: verified,
      );
      if (!verified) {
        logTaskStorage('auto-save verify failed for ${tasks.length} task(s)');
      }
    } catch (error, stack) {
      logTaskStorage('failed to save tasks: $error');
      debugPrint(stack.toString());
      logDiagAfterSaveTasks(
        savedTaskCount: tasks.length,
        storageReady: isStorageReady,
        setStringResult: false,
        verified: false,
        errorMessage: error.toString(),
      );
      logTaskAutoSave(
        taskCount: tasks.length,
        storageReady: isStorageReady,
        verified: false,
      );
    }
  }

  static Future<List<CategoryItem>> loadCategories() async {
    try {
      final prefs = await _ensurePrefs();
      if (prefs == null) return CategoryItem.defaults();

      final jsonString = prefs.getString(_categoriesKey);
      if (jsonString == null || jsonString.isEmpty) {
        return CategoryItem.defaults();
      }

      final decoded = jsonDecode(jsonString);
      if (decoded is! List<dynamic>) {
        debugPrint('Invalid categories payload: expected a JSON array');
        return CategoryItem.defaults();
      }

      final categories = <CategoryItem>[];
      for (final item in decoded) {
        if (item is! Map) {
          debugPrint('Skipping invalid category entry: $item');
          continue;
        }
        try {
          categories.add(
            CategoryItem.fromJson(Map<String, dynamic>.from(item)),
          );
        } catch (error, stack) {
          debugPrint('Skipping corrupt category entry: $error');
          debugPrint(stack.toString());
        }
      }

      final loaded =
          categories.isEmpty ? CategoryItem.defaults() : categories;
      return CategoryItem.ensureRegistrationDefaults(loaded);
    } catch (error, stack) {
      debugPrint('Failed to load categories: $error');
      debugPrint(stack.toString());
      return CategoryItem.defaults();
    }
  }

  static Future<String?> loadLastRegistrationCategoryId() async {
    try {
      final prefs = await _ensurePrefs();
      if (prefs == null) return null;

      final value = prefs.getString(_lastRegistrationCategoryKey);
      if (value == null || value.isEmpty) return null;
      return value;
    } catch (error, stack) {
      debugPrint('Failed to load last registration category: $error');
      debugPrint(stack.toString());
      return null;
    }
  }

  static Future<void> saveLastRegistrationCategoryId(String categoryId) async {
    try {
      final prefs = await _ensurePrefs();
      if (prefs == null) return;

      await prefs.setString(_lastRegistrationCategoryKey, categoryId);
    } catch (error, stack) {
      debugPrint('Failed to save last registration category: $error');
      debugPrint(stack.toString());
    }
  }

  static Future<void> saveCategories(List<CategoryItem> categories) async {
    try {
      final prefs = await _ensurePrefs();
      if (prefs == null) return;

      final jsonString = jsonEncode(categories.map((c) => c.toJson()).toList());
      await prefs.setString(_categoriesKey, jsonString);
    } catch (error, stack) {
      debugPrint('Failed to save categories: $error');
      debugPrint(stack.toString());
    }
  }

  static Future<ThemeMode> loadThemeMode() async {
    try {
      final prefs = await _ensurePrefs();
      if (prefs == null) return ThemeMode.system;

      final value = prefs.getString(_themeModeKey);
      return switch (value) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (error, stack) {
      debugPrint('Failed to load theme mode: $error');
      debugPrint(stack.toString());
      return ThemeMode.system;
    }
  }

  static Future<void> saveThemeMode(ThemeMode mode) async {
    try {
      final prefs = await _ensurePrefs();
      if (prefs == null) return;

      final value = switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      await prefs.setString(_themeModeKey, value);
    } catch (error, stack) {
      debugPrint('Failed to save theme mode: $error');
      debugPrint(stack.toString());
    }
  }

  static Future<FeedbackPreferences> loadFeedbackPreferences() async {
    try {
      final prefs = await _ensurePrefs();
      if (prefs == null) return FeedbackPreferences.defaults;

      final jsonString = prefs.getString(_feedbackPreferencesKey);
      if (jsonString == null || jsonString.isEmpty) {
        return FeedbackPreferences.defaults;
      }

      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        debugPrint('Invalid feedback preferences payload: expected a JSON object');
        return FeedbackPreferences.defaults;
      }

      return FeedbackPreferences.fromJson(decoded);
    } catch (error, stack) {
      debugPrint('Failed to load feedback preferences: $error');
      debugPrint(stack.toString());
      return FeedbackPreferences.defaults;
    }
  }

  static Future<void> saveFeedbackPreferences(
    FeedbackPreferences preferences,
  ) async {
    try {
      final prefs = await _ensurePrefs();
      if (prefs == null) return;

      await prefs.setString(
        _feedbackPreferencesKey,
        jsonEncode(preferences.toJson()),
      );
    } catch (error, stack) {
      debugPrint('Failed to save feedback preferences: $error');
      debugPrint(stack.toString());
    }
  }

  static Future<NotificationPreferences> loadNotificationPreferences() async {
    try {
      final prefs = await _ensurePrefs();
      if (prefs == null) return NotificationPreferences.defaults;

      final jsonString = prefs.getString(_notificationPreferencesKey);
      if (jsonString == null || jsonString.isEmpty) {
        return NotificationPreferences.defaults;
      }

      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        debugPrint(
          'Invalid notification preferences payload: expected a JSON object',
        );
        return NotificationPreferences.defaults;
      }

      return NotificationPreferences.fromJson(decoded);
    } catch (error, stack) {
      debugPrint('Failed to load notification preferences: $error');
      debugPrint(stack.toString());
      return NotificationPreferences.defaults;
    }
  }

  static Future<void> saveNotificationPreferences(
    NotificationPreferences preferences,
  ) async {
    try {
      final prefs = await _ensurePrefs();
      if (prefs == null) return;

      await prefs.setString(
        _notificationPreferencesKey,
        jsonEncode(preferences.toJson()),
      );
    } catch (error, stack) {
      debugPrint('Failed to save notification preferences: $error');
      debugPrint(stack.toString());
    }
  }

  static Future<CompletedTaskRetention> loadCompletedTaskRetention() async {
    try {
      final prefs = await _ensurePrefs();
      if (prefs == null) return CompletedTaskRetention.defaults;

      return CompletedTaskRetention.fromStorage(
        prefs.getString(_completedTaskRetentionKey),
      );
    } catch (error, stack) {
      debugPrint('Failed to load completed task retention: $error');
      debugPrint(stack.toString());
      return CompletedTaskRetention.defaults;
    }
  }

  static Future<void> saveCompletedTaskRetention(
    CompletedTaskRetention retention,
  ) async {
    try {
      final prefs = await _ensurePrefs();
      if (prefs == null) return;

      await prefs.setString(_completedTaskRetentionKey, retention.storageValue);
    } catch (error, stack) {
      debugPrint('Failed to save completed task retention: $error');
      debugPrint(stack.toString());
    }
  }

  /// 入力エリアの初回ガイドを表示すべきか
  static Future<bool> shouldShowInputGuidance() async {
    try {
      final prefs = await _ensurePrefs();
      if (prefs == null) return true;
      return !(prefs.getBool(_inputGuidanceSeenKey) ?? false);
    } catch (error, stack) {
      debugPrint('Failed to read input guidance flag: $error');
      debugPrint(stack.toString());
      return true;
    }
  }

  static Future<void> markInputGuidanceSeen() async {
    try {
      final prefs = await _ensurePrefs();
      if (prefs == null) return;
      await prefs.setBool(_inputGuidanceSeenKey, true);
    } catch (error, stack) {
      debugPrint('Failed to save input guidance flag: $error');
      debugPrint(stack.toString());
    }
  }

  /// Inbox（追加したタスク）エリアの初回ガイドを表示すべきか
  static Future<bool> shouldShowInboxGuidance() async {
    try {
      final prefs = await _ensurePrefs();
      if (prefs == null) return true;
      return !(prefs.getBool(_inboxGuidanceSeenKey) ?? false);
    } catch (error, stack) {
      debugPrint('Failed to read inbox guidance flag: $error');
      debugPrint(stack.toString());
      return true;
    }
  }

  static Future<void> markInboxGuidanceSeen() async {
    try {
      final prefs = await _ensurePrefs();
      if (prefs == null) return;
      await prefs.setBool(_inboxGuidanceSeenKey, true);
    } catch (error, stack) {
      debugPrint('Failed to save inbox guidance flag: $error');
      debugPrint(stack.toString());
    }
  }

  /// 固定（📌）ガイドを表示すべきか
  static Future<bool> shouldShowFavoriteGuidance() async {
    try {
      final prefs = await _ensurePrefs();
      if (prefs == null) return true;
      return !(prefs.getBool(_favoriteGuidanceSeenKey) ?? false);
    } catch (error, stack) {
      debugPrint('Failed to read favorite guidance flag: $error');
      debugPrint(stack.toString());
      return true;
    }
  }

  static Future<void> markFavoriteGuidanceSeen() async {
    try {
      final prefs = await _ensurePrefs();
      if (prefs == null) return;
      await prefs.setBool(_favoriteGuidanceSeenKey, true);
    } catch (error, stack) {
      debugPrint('Failed to save favorite guidance flag: $error');
      debugPrint(stack.toString());
    }
  }

  /// 初回起動時の通知権限確認をまだ行っていなければ true を返し、フラグを立てる
  static Future<bool> consumeNotificationPermissionPrompt() async {
    try {
      final prefs = await _ensurePrefs();
      if (prefs == null) return false;
      if (prefs.getBool(_notificationPermissionPromptedKey) ?? false) {
        return false;
      }
      await prefs.setBool(_notificationPermissionPromptedKey, true);
      return true;
    } catch (error, stack) {
      debugPrint('Failed to mark notification permission prompt: $error');
      debugPrint(stack.toString());
      return false;
    }
  }

  /// 初回起動イベントをまだ送っていなければ true を返し、フラグを立てる
  static Future<bool> consumeFirstLaunchForAnalytics() async {
    try {
      final prefs = await _ensurePrefs();
      if (prefs == null) return false;
      if (prefs.getBool(_firstLaunchLoggedKey) ?? false) return false;
      await prefs.setBool(_firstLaunchLoggedKey, true);
      return true;
    } catch (error, stack) {
      debugPrint('Failed to mark first launch: $error');
      debugPrint(stack.toString());
      return false;
    }
  }
}

class _TaskLoadSnapshot {
  const _TaskLoadSnapshot({
    required this.tasks,
    required this.storageReady,
    required this.hadPersistedPayload,
    this.payloadBytes,
    this.errorMessage,
    this.rawJson,
  });

  final List<Task> tasks;
  final bool storageReady;
  final bool hadPersistedPayload;
  final int? payloadBytes;
  final String? errorMessage;
  final String? rawJson;
}

class PersistedTaskSnapshot {
  const PersistedTaskSnapshot({
    required this.storageReady,
    required this.hadPersistedPayload,
    required this.taskCount,
    required this.rawJson,
  });

  final bool storageReady;
  final bool hadPersistedPayload;
  final int taskCount;
  final String rawJson;
}
