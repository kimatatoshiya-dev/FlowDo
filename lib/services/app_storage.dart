import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/category_item.dart';
import '../models/completed_task_retention.dart';
import '../models/feedback_preferences.dart';
import '../models/task.dart';

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
  static const _completedTaskRetentionKey = 'flowdo_completed_task_retention';
  static const _firstLaunchLoggedKey = 'flowdo_analytics_first_launch_logged';
  static const _inputGuidanceSeenKey = 'flowdo_input_guidance_seen';
  static const _inboxGuidanceSeenKey = 'flowdo_inbox_guidance_seen';
  static const _favoriteGuidanceSeenKey = 'flowdo_favorite_guidance_seen';
  static const _maxPrefsAttempts = 8;
  static const _prefsRetryBaseDelay = Duration(milliseconds: 150);

  static SharedPreferences? _cachedPrefs;
  static bool _prefsPermanentlyUnavailable = false;

  /// iOS 実機でプラグイン初期化が遅れる場合に備え、起動時に先に温める
  static Future<bool> warmUp() async {
    final prefs = await _ensurePrefs(forceRetry: true);
    return prefs != null;
  }

  /// SharedPreferences を取得する。失敗時は null（例外は投げない）
  static Future<SharedPreferences?> _ensurePrefs({bool forceRetry = false}) async {
    if (_prefsPermanentlyUnavailable && !forceRetry) {
      return null;
    }

    if (_cachedPrefs != null && !forceRetry) {
      return _cachedPrefs;
    }

    if (forceRetry) {
      _prefsPermanentlyUnavailable = false;
    }

    for (var attempt = 0; attempt < _maxPrefsAttempts; attempt++) {
      try {
        final prefs = await SharedPreferences.getInstance();
        _cachedPrefs = prefs;
        _prefsPermanentlyUnavailable = false;
        return prefs;
      } catch (error, stack) {
        debugPrint(
          'SharedPreferences unavailable (attempt ${attempt + 1}/$_maxPrefsAttempts): $error',
        );
        debugPrint(stack.toString());
        if (attempt < _maxPrefsAttempts - 1) {
          await Future<void>.delayed(
            _prefsRetryBaseDelay * (attempt + 1),
          );
        }
      }
    }

    _prefsPermanentlyUnavailable = true;
    _cachedPrefs = null;
    debugPrint(
      'SharedPreferences permanently unavailable; using in-memory defaults',
    );
    return null;
  }

  static Future<List<Task>> loadTasks() async {
    try {
      final prefs = await _ensurePrefs();
      if (prefs == null) return [];

      final jsonString = prefs.getString(_tasksKey);
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final decoded = jsonDecode(jsonString);
      if (decoded is! List<dynamic>) {
        debugPrint('Invalid tasks payload: expected a JSON array');
        return [];
      }

      final tasks = <Task>[];
      for (final item in decoded) {
        if (item is! Map) {
          debugPrint('Skipping invalid task entry: $item');
          continue;
        }
        try {
          tasks.add(Task.fromJson(Map<String, dynamic>.from(item)));
        } catch (error, stack) {
          debugPrint('Skipping corrupt task entry: $error');
          debugPrint(stack.toString());
        }
      }

      Task.syncNextId(tasks);
      return tasks;
    } catch (error, stack) {
      debugPrint('Failed to load tasks: $error');
      debugPrint(stack.toString());
      return [];
    }
  }

  static Future<void> saveTasks(List<Task> tasks) async {
    try {
      final prefs = await _ensurePrefs();
      if (prefs == null) return;

      final jsonString = jsonEncode(tasks.map((t) => t.toJson()).toList());
      await prefs.setString(_tasksKey, jsonString);
    } catch (error, stack) {
      debugPrint('Failed to save tasks: $error');
      debugPrint(stack.toString());
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
