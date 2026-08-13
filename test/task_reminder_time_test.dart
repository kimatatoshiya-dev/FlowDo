import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/models/notification_preferences.dart';
import 'package:flowdo/models/task.dart';
import 'package:flowdo/models/task_repeat_type.dart';
import 'package:flowdo/services/task_notification_service.dart';

void main() {
  group('Task reminderTime JSON', () {
    test('roundtrips through toJson/fromJson', () {
      final task = Task(
        id: 1,
        title: '会議',
        isInbox: false,
        dueDate: DateTime(2026, 8, 17),
        reminderTime: const TimeOfDay(hour: 10, minute: 30),
      );

      final restored = Task.fromJson(task.toJson());

      expect(restored.reminderTime, const TimeOfDay(hour: 10, minute: 30));
    });

    test('parseReminderTime rejects invalid values', () {
      expect(Task.parseReminderTime('25:00'), isNull);
      expect(Task.parseReminderTime('abc'), isNull);
      expect(Task.parseReminderTime('09:15'), const TimeOfDay(hour: 9, minute: 15));
    });
  });

  group('shouldScheduleTaskNotification', () {
    test('時間設定済みの未完了タスクのみ対象', () {
      final task = Task(
        id: 1,
        title: '会議',
        isInbox: false,
        dueDate: DateTime(2026, 8, 17),
        reminderTime: const TimeOfDay(hour: 10, minute: 30),
      );

      expect(
        shouldScheduleTaskNotification(task, NotificationPreferences.defaults),
        isTrue,
      );
      expect(
        shouldScheduleTaskNotification(
          Task(
            id: 2,
            title: '日付のみ',
            dueDate: DateTime(2026, 8, 17),
          ),
          NotificationPreferences.defaults,
        ),
        isFalse,
      );
      expect(
        shouldScheduleTaskNotification(
          task,
          const NotificationPreferences(enabled: false),
        ),
        isFalse,
      );
      expect(
        shouldScheduleTaskNotification(
          Task(
            id: 3,
            title: '完了済み',
            isCompleted: true,
            dueDate: DateTime(2026, 8, 17),
            reminderTime: const TimeOfDay(hour: 10, minute: 30),
          ),
          NotificationPreferences.defaults,
        ),
        isFalse,
      );
    });

    test('毎日ルーティンは dueDate なしでも対象', () {
      final task = Task(
        id: 4,
        title: '朝のルーティン',
        reminderTime: const TimeOfDay(hour: 7, minute: 0),
        repeatType: TaskRepeatType.daily,
      );

      expect(
        shouldScheduleTaskNotification(task, NotificationPreferences.defaults),
        isTrue,
      );
    });

    test('weekly 以上は dueDate が必要', () {
      final weekly = Task(
        id: 5,
        title: '週次',
        reminderTime: const TimeOfDay(hour: 9, minute: 0),
        repeatType: TaskRepeatType.weekly,
      );

      expect(
        shouldScheduleTaskNotification(weekly, NotificationPreferences.defaults),
        isFalse,
      );

      weekly.dueDate = DateTime(2026, 8, 17);
      expect(
        shouldScheduleTaskNotification(weekly, NotificationPreferences.defaults),
        isTrue,
      );
    });
  });

  group('notificationDateTimeForTask', () {
    test('15分前の通知時刻を返す', () {
      final task = Task(
        id: 1,
        title: '会議',
        isInbox: false,
        dueDate: DateTime(2026, 8, 17),
        reminderTime: const TimeOfDay(hour: 10, minute: 30),
      );

      final scheduledAt = notificationDateTimeForTask(
        task,
        NotificationPreferences.defaults,
      );

      expect(
        scheduledAt,
        DateTime(2026, 8, 17, 10, 15),
      );
    });

    test('時間ちょうど・10分前・前日を計算する', () {
      final task = Task(
        id: 1,
        title: '会議',
        dueDate: DateTime(2026, 8, 17),
        reminderTime: const TimeOfDay(hour: 10, minute: 30),
      );

      expect(
        notificationDateTimeForTask(
          task,
          const NotificationPreferences(leadTime: NotificationLeadTime.atTime),
        ),
        DateTime(2026, 8, 17, 10, 30),
      );
      expect(
        notificationDateTimeForTask(
          task,
          const NotificationPreferences(leadTime: NotificationLeadTime.minutes10),
        ),
        DateTime(2026, 8, 17, 10, 20),
      );
      expect(
        notificationDateTimeForTask(
          task,
          const NotificationPreferences(leadTime: NotificationLeadTime.dayBefore),
        ),
        DateTime(2026, 8, 16, 10, 30),
      );
    });

    test('通知OFFまたは時間なしの場合は null', () {
      final task = Task(
        id: 1,
        title: '会議',
        isInbox: false,
        dueDate: DateTime(2026, 8, 17),
      );

      expect(
        notificationDateTimeForTask(task, NotificationPreferences.defaults),
        isNull,
      );
      expect(
        notificationDateTimeForTask(
          task.copyWithReminderTime(const TimeOfDay(hour: 9, minute: 0)),
          const NotificationPreferences(enabled: false),
        ),
        isNull,
      );
      expect(
        notificationDateTimeForTask(
          task.copyWithReminderTime(const TimeOfDay(hour: 9, minute: 0)),
          const NotificationPreferences(
            leadTime: NotificationLeadTime.none,
          ),
        ),
        isNull,
      );
    });
  });

  group('notificationBodyForTask', () {
    test('仕様通りの本文を返す', () {
      final task = Task(id: 1, title: '会議');

      expect(
        notificationBodyForTask(task, NotificationLeadTime.minutes15),
        '「会議」まであと15分です。',
      );
      expect(
        notificationBodyForTask(task, NotificationLeadTime.atTime),
        '今日の予定です。',
      );
      expect(
        notificationBodyForTask(task, NotificationLeadTime.dayBefore),
        '「会議」まであと1日です。',
      );
    });
  });

  group('repeatComponentsForTask', () {
    test('repeatType に応じた繰り返し単位を返す', () {
      final task = Task(id: 1, title: 'Routine', repeatType: TaskRepeatType.daily);

      expect(repeatComponentsForTask(task), DateTimeComponents.time);

      task.repeatType = TaskRepeatType.weekly;
      expect(
        repeatComponentsForTask(task),
        DateTimeComponents.dayOfWeekAndTime,
      );

      task.repeatType = TaskRepeatType.monthly;
      expect(
        repeatComponentsForTask(task),
        DateTimeComponents.dayOfMonthAndTime,
      );

      task.repeatType = TaskRepeatType.yearly;
      expect(repeatComponentsForTask(task), DateTimeComponents.dateAndTime);

      task.repeatType = TaskRepeatType.none;
      expect(repeatComponentsForTask(task), isNull);
    });
  });
}

extension on Task {
  Task copyWithReminderTime(TimeOfDay? reminderTime) {
    return Task(
      id: id,
      title: title,
      isInbox: isInbox,
      dueDate: dueDate,
      reminderTime: reminderTime,
    );
  }
}
