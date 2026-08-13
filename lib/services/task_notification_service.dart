import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../config/app_features.dart';
import '../models/notification_preferences.dart';
import '../models/task.dart';
import '../models/task_repeat_type.dart';

/// 通知タップ時に taskId を渡すコールバック
typedef TaskNotificationTapCallback = void Function(int taskId);

/// タスク通知のスケジュール管理
abstract class TaskNotificationService {
  TaskNotificationTapCallback? onNotificationTap;

  NotificationPreferences get preferences;

  void updatePreferences(NotificationPreferences preferences);

  Future<void> initialize();

  Future<bool> requestPermissions();

  Future<bool> hasPermissions();

  Future<void> scheduleTaskNotification(Task task);

  Future<void> syncTasks(List<Task> tasks);

  Future<void> cancelTask(int taskId);

  Future<List<PendingNotificationRequest>> pendingNotifications();

  /// 通知タップで起動した場合の taskId（なければ null）
  Future<int?> readLaunchNotificationTaskId();

  Future<void> dispose();
}

/// 通知対象かどうか（テスト用に公開）
bool shouldScheduleTaskNotification(
  Task task,
  NotificationPreferences preferences,
) {
  if (!preferences.enabled) return false;
  if (preferences.leadTime == NotificationLeadTime.none) return false;
  if (task.isCompleted) return false;
  if (task.reminderTime == null) return false;

  if (task.repeatType != TaskRepeatType.none) {
    if (task.repeatType == TaskRepeatType.daily) return true;
    return task.dueDate != null;
  }

  return task.dueDate != null;
}

/// タスクの予定日時（リマインド時刻）
DateTime? taskEventDateTime(Task task, {DateTime? referenceNow}) {
  final reminderTime = task.reminderTime;
  if (reminderTime == null) return null;

  final now = referenceNow ?? DateTime.now();

  if (task.repeatType == TaskRepeatType.daily && task.dueDate == null) {
    var candidate = DateTime(
      now.year,
      now.month,
      now.day,
      reminderTime.hour,
      reminderTime.minute,
    );
    if (!candidate.isAfter(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  final dueDate = task.dueDate;
  if (dueDate == null) return null;

  var event = DateTime(
    dueDate.year,
    dueDate.month,
    dueDate.day,
    reminderTime.hour,
    reminderTime.minute,
  );

  if (task.repeatType != TaskRepeatType.none) {
    while (!event.isAfter(now)) {
      event = advanceTaskRecurrence(event, task.repeatType);
    }
  }

  return event;
}

DateTime advanceTaskRecurrence(DateTime dateTime, TaskRepeatType repeatType) {
  return switch (repeatType) {
    TaskRepeatType.daily => dateTime.add(const Duration(days: 1)),
    TaskRepeatType.weekly => dateTime.add(const Duration(days: 7)),
    TaskRepeatType.monthly => DateTime(
        dateTime.year,
        dateTime.month + 1,
        dateTime.day,
        dateTime.hour,
        dateTime.minute,
      ),
    TaskRepeatType.yearly => DateTime(
        dateTime.year + 1,
        dateTime.month,
        dateTime.day,
        dateTime.hour,
        dateTime.minute,
      ),
    TaskRepeatType.none => dateTime,
  };
}

/// 通知日時の計算（テスト用に公開）
DateTime? notificationDateTimeForTask(
  Task task,
  NotificationPreferences preferences, {
  DateTime? referenceNow,
}) {
  if (!shouldScheduleTaskNotification(task, preferences)) return null;

  final leadDuration = preferences.leadTime.leadDuration;
  if (leadDuration == null) return null;

  final event = taskEventDateTime(task, referenceNow: referenceNow);
  if (event == null) return null;

  return event.subtract(leadDuration);
}

/// 次に発火する通知日時（繰り返しタスクは未来の日時へ繰り上げ）
DateTime? nextNotificationDateTimeForTask(
  Task task,
  NotificationPreferences preferences, {
  DateTime? referenceNow,
}) {
  var scheduled = notificationDateTimeForTask(
    task,
    preferences,
    referenceNow: referenceNow,
  );
  if (scheduled == null) return null;

  final now = referenceNow ?? DateTime.now();
  if (task.repeatType == TaskRepeatType.none) {
    return scheduled.isAfter(now) ? scheduled : null;
  }

  var nextScheduled = scheduled;
  while (!nextScheduled.isAfter(now)) {
    nextScheduled = advanceTaskRecurrence(nextScheduled, task.repeatType);
  }
  return nextScheduled;
}

/// 通知本文（テスト用に公開）
String notificationBodyForTask(Task task, NotificationLeadTime leadTime) {
  if (leadTime == NotificationLeadTime.atTime) {
    return '今日の予定です。';
  }
  if (leadTime == NotificationLeadTime.dayBefore) {
    return '「${task.title}」まであと1日です。';
  }
  return '「${task.title}」まであと${leadTime.bodyLabel}です。';
}

DateTimeComponents? repeatComponentsForTask(Task task) {
  return switch (task.repeatType) {
    TaskRepeatType.daily => DateTimeComponents.time,
    TaskRepeatType.weekly => DateTimeComponents.dayOfWeekAndTime,
    TaskRepeatType.monthly => DateTimeComponents.dayOfMonthAndTime,
    TaskRepeatType.yearly => DateTimeComponents.dateAndTime,
    TaskRepeatType.none => null,
  };
}

/// flutter_local_notifications による実装
class NativeTaskNotificationService implements TaskNotificationService {
  NativeTaskNotificationService([
    NotificationPreferences? preferences,
  ]) : _preferences = preferences ?? NotificationPreferences.defaults;

  static const _channelId = 'flowdo_task_reminders';
  static const _channelName = 'タスクリマインダー';
  static const _channelDescription = '時間指定タスクの開始前通知';
  static const _logTag = '[FlowDoNotif]';

  NotificationPreferences _preferences;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Future<void>? _initializationFuture;

  @override
  TaskNotificationTapCallback? onNotificationTap;

  @override
  NotificationPreferences get preferences => _preferences;

  @override
  void updatePreferences(NotificationPreferences preferences) {
    _preferences = preferences;
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _initializationFuture ??= _initializeInternal();
    try {
      await _initializationFuture;
    } catch (_) {
      // 呼び出し元へ例外を伝播させない（通知失敗でアプリ全体を止めない）
    }
  }

  @override
  Future<void> initialize() => _ensureInitialized();

  Future<void> _initializeInternal() async {
    if (_initialized) return;

    try {
      tz_data.initializeTimeZones();
      await _configureLocalTimeZone();

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
          ),
        );
        await androidPlugin?.requestExactAlarmsPermission();
      }

      _initialized = true;
      _log('initialize complete');
    } catch (error, stack) {
      _initialized = false;
      _initializationFuture = null;
      _log('initialize failed: $error');
      debugPrint(stack.toString());
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final taskId = int.tryParse(response.payload ?? '');
    if (taskId == null) return;
    onNotificationTap?.call(taskId);
  }

  Future<void> _configureLocalTimeZone() async {
    try {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));
      _log('timezone=${timeZoneInfo.identifier}');
    } catch (error, stack) {
      _log('timezone lookup failed: $error');
      debugPrint(stack.toString());
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
    }
  }

  @override
  Future<bool> requestPermissions() async {
    try {
      await _ensureInitialized();
    } catch (error, stack) {
      _log('requestPermissions aborted (init failed): $error');
      debugPrint(stack.toString());
      return false;
    }
    if (!_initialized) return false;
    if (kIsWeb) return false;

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final notificationsGranted =
            await androidPlugin?.requestNotificationsPermission();
        await androidPlugin?.requestExactAlarmsPermission();
        final granted = notificationsGranted ?? false;
        _log('requestPermissions(android) granted=$granted');
        return granted;
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final granted = await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
        final result = granted ?? false;
        _log('requestPermissions(ios) granted=$result');
        return result;
      }

      if (defaultTargetPlatform == TargetPlatform.macOS) {
        final granted = await _plugin
            .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
        final result = granted ?? false;
        _log('requestPermissions(macos) granted=$result');
        return result;
      }

      return true;
    } catch (error, stack) {
      _log('requestPermissions failed: $error');
      debugPrint(stack.toString());
      return false;
    }
  }

  @override
  Future<bool> hasPermissions() async {
    try {
      await _ensureInitialized();
    } catch (error, stack) {
      _log('hasPermissions aborted (init failed): $error');
      debugPrint(stack.toString());
      return false;
    }
    if (!_initialized) return false;
    if (kIsWeb) return false;

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final enabled = await androidPlugin?.areNotificationsEnabled();
        return enabled ?? false;
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final options = await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.checkPermissions();
        return options?.isEnabled ?? false;
      }

      if (defaultTargetPlatform == TargetPlatform.macOS) {
        final options = await _plugin
            .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin>()
            ?.checkPermissions();
        return options?.isEnabled ?? false;
      }

      return true;
    } catch (error, stack) {
      _log('hasPermissions failed: $error');
      debugPrint(stack.toString());
      return false;
    }
  }

  @override
  Future<void> scheduleTaskNotification(Task task) async {
    _log(
      'scheduleTaskNotification called '
      'taskId=${task.id} title="${task.title}" '
      'dueDate=${task.dueDate} reminderTime=${task.reminderTime} '
      'repeatType=${task.repeatType.name}',
    );

    try {
      await _ensureInitialized();
    } catch (error, stack) {
      _log('scheduleTaskNotification aborted (init failed): $error');
      debugPrint(stack.toString());
      return;
    }

    if (!shouldScheduleTaskNotification(task, _preferences)) {
      _log('scheduleTaskNotification skip (not eligible)');
      await cancelTask(task.id);
      return;
    }

    if (!await hasPermissions()) {
      _log('scheduleTaskNotification skip (permission not granted)');
      return;
    }

    await _scheduleTask(task);
  }

  @override
  Future<void> syncTasks(List<Task> tasks) async {
    try {
      await _ensureInitialized();
    } catch (error, stack) {
      _log('syncTasks aborted (init failed): $error');
      debugPrint(stack.toString());
      return;
    }

    final scheduledIds = <int>{};

    for (final task in tasks) {
      if (shouldScheduleTaskNotification(task, _preferences)) {
        scheduledIds.add(task.id);
        await _scheduleTask(task);
      } else {
        await cancelTask(task.id);
      }
    }

    await _cancelOrphanedNotifications(scheduledIds);
  }

  Future<void> _cancelOrphanedNotifications(Set<int> scheduledIds) async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        if (!scheduledIds.contains(request.id)) {
          await _plugin.cancel(id: request.id);
        }
      }
    } catch (error, stack) {
      _log('cancel orphaned failed: $error');
      debugPrint(stack.toString());
    }
  }

  @override
  Future<void> cancelTask(int taskId) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: taskId);
      _log('cancelTask taskId=$taskId');
    } catch (error, stack) {
      _log('cancelTask failed taskId=$taskId error=$error');
      debugPrint(stack.toString());
    }
  }

  @override
  Future<List<PendingNotificationRequest>> pendingNotifications() async {
    if (!_initialized) return const [];
    try {
      return await _plugin.pendingNotificationRequests();
    } catch (error, stack) {
      _log('pendingNotifications failed: $error');
      debugPrint(stack.toString());
      return const [];
    }
  }

  @override
  Future<int?> readLaunchNotificationTaskId() async {
    try {
      await _ensureInitialized();
    } catch (_) {
      return null;
    }
    if (!_initialized) return null;

    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return null;
      return int.tryParse(details!.notificationResponse?.payload ?? '');
    } catch (error, stack) {
      _log('readLaunchNotificationTaskId failed: $error');
      debugPrint(stack.toString());
      return null;
    }
  }

  @override
  Future<void> dispose() async {}

  Future<void> _scheduleTask(Task task) async {
    final scheduledAt = nextNotificationDateTimeForTask(task, _preferences);
    if (scheduledAt == null) {
      _log('_scheduleTask skip (no schedule time) taskId=${task.id}');
      await cancelTask(task.id);
      return;
    }

    await cancelTask(task.id);

    final tzScheduled = tz.TZDateTime(
      tz.local,
      scheduledAt.year,
      scheduledAt.month,
      scheduledAt.day,
      scheduledAt.hour,
      scheduledAt.minute,
    );

    final repeatComponents = repeatComponentsForTask(task);
    _log(
      'zonedSchedule start taskId=${task.id} '
      'local=$scheduledAt tz=$tzScheduled lead=${_preferences.leadTime.label} '
      'repeat=${repeatComponents?.name ?? 'once'}',
    );

    try {
      await _plugin.zonedSchedule(
        id: task.id,
        title: 'FlowDo',
        body: notificationBodyForTask(task, _preferences.leadTime),
        scheduledDate: tzScheduled,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: '${task.id}',
        matchDateTimeComponents: repeatComponents,
      );

      final pending = await pendingNotifications();
      final registered = pending.any((request) => request.id == task.id);
      _log(
        'zonedSchedule done taskId=${task.id} registered=$registered '
        'pendingCount=${pending.length}',
      );
    } catch (error, stack) {
      _log('zonedSchedule failed taskId=${task.id} error=$error');
      debugPrint(stack.toString());
    }
  }

  void _log(String message) {
    debugPrint('$_logTag $message');
  }
}

/// 機能フラグに応じた通知サービスを生成する
TaskNotificationService createTaskNotificationService([
  NotificationPreferences? preferences,
]) {
  if (!kTaskNotificationsEnabled) {
    return NoOpTaskNotificationService(preferences);
  }
  return NativeTaskNotificationService(preferences);
}

/// 起動後に安全に通知基盤を初期化する（失敗しても例外を外に出さない）
Future<void> safeInitializeTaskNotifications(
  TaskNotificationService service,
) async {
  if (!kTaskNotificationsEnabled) return;

  try {
    await service.initialize();
  } catch (error, stack) {
    debugPrint('[FlowDoNotif] safeInitialize failed: $error');
    debugPrint(stack.toString());
  }
}

/// テスト用 no-op 実装
class NoOpTaskNotificationService implements TaskNotificationService {
  NoOpTaskNotificationService([
    NotificationPreferences? preferences,
  ]) : _preferences = preferences ?? NotificationPreferences.defaults;

  NotificationPreferences _preferences;

  @override
  TaskNotificationTapCallback? onNotificationTap;

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
  Future<bool> hasPermissions() async => true;

  @override
  Future<void> scheduleTaskNotification(Task task) async {}

  @override
  Future<void> syncTasks(List<Task> tasks) async {}

  @override
  Future<void> cancelTask(int taskId) async {}

  @override
  Future<List<PendingNotificationRequest>> pendingNotifications() async {
    return const [];
  }

  @override
  Future<int?> readLaunchNotificationTaskId() async => null;

  @override
  Future<void> dispose() async {}
}

/// テスト用: 呼び出しを記録する
class RecordingTaskNotificationService implements TaskNotificationService {
  RecordingTaskNotificationService([
    NotificationPreferences? preferences,
  ]) : _preferences = preferences ?? NotificationPreferences.defaults;

  NotificationPreferences _preferences;
  final scheduledTaskIds = <int>[];
  final cancelledTaskIds = <int>[];

  @override
  TaskNotificationTapCallback? onNotificationTap;

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
  Future<bool> hasPermissions() async => true;

  @override
  Future<void> scheduleTaskNotification(Task task) async {
    scheduledTaskIds.add(task.id);
  }

  @override
  Future<void> syncTasks(List<Task> tasks) async {}

  @override
  Future<void> cancelTask(int taskId) async {
    cancelledTaskIds.add(taskId);
  }

  @override
  Future<List<PendingNotificationRequest>> pendingNotifications() async {
    return const [];
  }

  @override
  Future<int?> readLaunchNotificationTaskId() async => null;

  @override
  Future<void> dispose() async {}
}
