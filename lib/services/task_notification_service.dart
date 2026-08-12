import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/notification_preferences.dart';
import '../models/task.dart';

/// タスク通知のスケジュール管理
abstract class TaskNotificationService {
  NotificationPreferences get preferences;

  void updatePreferences(NotificationPreferences preferences);

  Future<void> initialize();

  Future<bool> requestPermissions();

  Future<void> syncTasks(List<Task> tasks);

  Future<void> cancelTask(int taskId);

  Future<void> dispose();
}

/// flutter_local_notifications による実装
class NativeTaskNotificationService implements TaskNotificationService {
  NativeTaskNotificationService([
    NotificationPreferences? preferences,
  ]) : _preferences = preferences ?? NotificationPreferences.defaults;

  static const _channelId = 'flowdo_task_reminders';
  static const _channelName = 'タスクリマインダー';
  static const _channelDescription = '時間指定タスクの開始前通知';

  NotificationPreferences _preferences;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  @override
  NotificationPreferences get preferences => _preferences;

  @override
  void updatePreferences(NotificationPreferences preferences) {
    _preferences = preferences;
  }

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.local);
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings: settings,
    );

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: _channelDescription,
              importance: Importance.high,
            ),
          );
    }

    _initialized = true;
  }

  @override
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return granted ?? false;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return granted ?? false;
    }

    return true;
  }

  @override
  Future<void> syncTasks(List<Task> tasks) async {
    if (!_initialized) {
      await initialize();
    }

    for (final task in tasks) {
      if (_shouldSchedule(task)) {
        await _scheduleTask(task);
      } else {
        await cancelTask(task.id);
      }
    }
  }

  @override
  Future<void> cancelTask(int taskId) async {
    if (!_initialized) return;
    await _plugin.cancel(id: taskId);
  }

  @override
  Future<void> dispose() async {}

  bool _shouldSchedule(Task task) {
    if (!_preferences.enabled) return false;
    if (_preferences.leadTime == NotificationLeadTime.none) return false;
    if (task.isCompleted) return false;
    if (task.dueDate == null || task.reminderTime == null) return false;
    return true;
  }

  DateTime? _notificationDateTime(Task task) {
    final leadDuration = _preferences.leadTime.leadDuration;
    if (leadDuration == null) return null;

    final due = task.dueDate!;
    final time = task.reminderTime!;
    final dueDateTime = DateTime(
      due.year,
      due.month,
      due.day,
      time.hour,
      time.minute,
    );
    return dueDateTime.subtract(leadDuration);
  }

  Future<void> _scheduleTask(Task task) async {
    final scheduledAt = _notificationDateTime(task);
    if (scheduledAt == null) {
      await cancelTask(task.id);
      return;
    }

    if (!scheduledAt.isAfter(DateTime.now())) {
      await cancelTask(task.id);
      return;
    }

    await _plugin.zonedSchedule(
      id: task.id,
      title: 'FlowDo',
      body: '「${task.title}」の時間です。まもなく開始予定です。',
      scheduledDate: tz.TZDateTime.from(scheduledAt, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
}

/// テスト用 no-op 実装
class NoOpTaskNotificationService implements TaskNotificationService {
  NoOpTaskNotificationService([
    NotificationPreferences? preferences,
  ]) : _preferences = preferences ?? NotificationPreferences.defaults;

  NotificationPreferences _preferences;

  @override
  NotificationPreferences get preferences => _preferences;

  @override
  void updatePreferences(NotificationPreferences preferences) {
    _preferences = preferences;
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> syncTasks(List<Task> tasks) async {}

  @override
  Future<void> cancelTask(int taskId) async {}

  @override
  Future<void> dispose() async {}
}

/// 通知日時の計算（テスト用に公開）
DateTime? notificationDateTimeForTask(
  Task task,
  NotificationPreferences preferences,
) {
  if (!preferences.enabled) return null;
  final leadDuration = preferences.leadTime.leadDuration;
  if (leadDuration == null) return null;
  if (task.isCompleted) return null;
  if (task.dueDate == null || task.reminderTime == null) return null;

  final due = task.dueDate!;
  final time = task.reminderTime!;
  final dueDateTime = DateTime(
    due.year,
    due.month,
    due.day,
    time.hour,
    time.minute,
  );
  return dueDateTime.subtract(leadDuration);
}
