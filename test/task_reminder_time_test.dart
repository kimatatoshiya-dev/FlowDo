import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/models/notification_preferences.dart';
import 'package:flowdo/models/task.dart';
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
