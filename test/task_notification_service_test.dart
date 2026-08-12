import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/models/notification_preferences.dart';
import 'package:flowdo/models/task.dart';
import 'package:flowdo/services/task_notification_service.dart';

void main() {
  group('RecordingTaskNotificationService', () {
    test('scheduleTaskNotification を記録する', () async {
      final service = RecordingTaskNotificationService();
      final task = Task(
        id: 7,
        title: '会議',
        isInbox: false,
        dueDate: DateTime(2026, 8, 17),
        reminderTime: const TimeOfDay(hour: 10, minute: 30),
      );

      await service.scheduleTaskNotification(task);

      expect(service.scheduledTaskIds, [7]);
    });

    test('cancelTask を記録する', () async {
      final service = RecordingTaskNotificationService();
      await service.cancelTask(3);
      expect(service.cancelledTaskIds, [3]);
    });
  });

  group('scheduleTaskNotification eligibility', () {
    test('時間と期限があるタスクのみスケジュール対象', () {
      final task = Task(
        id: 1,
        title: 'Alpha',
        dueDate: DateTime(2026, 8, 17),
        reminderTime: const TimeOfDay(hour: 10, minute: 0),
      );

      expect(
        shouldScheduleTaskNotification(task, NotificationPreferences.defaults),
        isTrue,
      );
      expect(
        shouldScheduleTaskNotification(
          Task(id: 2, title: 'No time', dueDate: DateTime(2026, 8, 17)),
          NotificationPreferences.defaults,
        ),
        isFalse,
      );
    });
  });

  group('reminderTime save harness', () {
    test('reminderTime 保存時に scheduleTaskNotification が呼ばれる', () async {
      final service = RecordingTaskNotificationService();
      final task = Task(
        id: 42,
        title: 'テスト',
        isInbox: false,
        dueDate: DateTime(2026, 8, 17),
      );

      await _applyReminderTime(service, task, const TimeOfDay(hour: 11, minute: 15));

      expect(task.reminderTime, const TimeOfDay(hour: 11, minute: 15));
      expect(service.scheduledTaskIds, [42]);
    });

    test('reminderTime クリア時に cancelTask が呼ばれる', () async {
      final service = RecordingTaskNotificationService();
      final task = Task(
        id: 5,
        title: 'テスト',
        dueDate: DateTime(2026, 8, 17),
        reminderTime: const TimeOfDay(hour: 9, minute: 0),
      );

      await _applyReminderTime(service, task, null);

      expect(task.reminderTime, isNull);
      expect(service.cancelledTaskIds, [5]);
    });
  });
}

Future<void> _applyReminderTime(
  RecordingTaskNotificationService notificationService,
  Task task,
  TimeOfDay? reminderTime,
) async {
  task.reminderTime = reminderTime;

  if (reminderTime == null ||
      task.dueDate == null ||
      task.isCompleted ||
      !notificationService.preferences.enabled ||
      notificationService.preferences.leadTime == NotificationLeadTime.none) {
    await notificationService.cancelTask(task.id);
    return;
  }

  if (!await notificationService.hasPermissions()) {
    await notificationService.requestPermissions();
  }

  await notificationService.scheduleTaskNotification(task);
}
