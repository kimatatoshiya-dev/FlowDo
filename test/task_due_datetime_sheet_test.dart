import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/models/notification_preferences.dart';
import 'package:flowdo/models/task.dart';
import 'package:flowdo/models/task_repeat_type.dart';
import 'package:flowdo/theme/app_theme.dart';
import 'package:flowdo/utils/date_formatter.dart';
import 'package:flowdo/widgets/task_due_datetime_sheet.dart';

void main() {
  testWidgets('期限未設定時は期限なし行を表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TaskDueDateTimeSheet(
            initialDueDate: null,
            initialReminderTime: null,
            initialRepeatType: TaskRepeatType.none,
            notificationPreferences: NotificationPreferences.defaults,
            notificationsFeatureEnabled: true,
            checkNotificationPermission: () async => true,
            onRequestNotificationPermission: () async => true,
            onDueDateChanged: (_) async {},
            onReminderTimeChanged: (_) async {},
            onRepeatTypeChanged: (_) async {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('due_date_empty_row')), findsOneWidget);
    expect(find.text(DateFormatter.noDueDateLabel), findsOneWidget);
    expect(find.byKey(const ValueKey('due_repeat_row')), findsNothing);
  });

  testWidgets('期限設定済みは日付・時間・繰り返し・通知をまとめて表示する',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TaskDueDateTimeSheet(
            initialDueDate: DateTime(2026, 8, 17),
            initialReminderTime: const TimeOfDay(hour: 9, minute: 0),
            initialRepeatType: TaskRepeatType.weekly,
            notificationPreferences: NotificationPreferences.defaults,
            notificationsFeatureEnabled: true,
            checkNotificationPermission: () async => true,
            onDueDateChanged: (_) async {},
            onReminderTimeChanged: (_) async {},
            onRepeatTypeChanged: (_) async {},
            onRequestNotificationPermission: () async => true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2026/08/17'), findsOneWidget);
    expect(find.text('🕘 09:00'), findsOneWidget);
    expect(find.text('毎週'), findsOneWidget);
    expect(find.text('通知'), findsOneWidget);
    expect(find.text('ON'), findsOneWidget);
    expect(find.textContaining('準備中'), findsNothing);
    expect(find.byIcon(Icons.lock), findsNothing);
  });

  testWidgets('通知権限がない場合は許可ボタンを表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TaskDueDateTimeSheet(
            initialDueDate: DateTime(2026, 8, 17),
            initialReminderTime: const TimeOfDay(hour: 9, minute: 0),
            initialRepeatType: TaskRepeatType.none,
            notificationPreferences: NotificationPreferences.defaults,
            notificationsFeatureEnabled: true,
            checkNotificationPermission: () async => false,
            onRequestNotificationPermission: () async => true,
            onDueDateChanged: (_) async {},
            onReminderTimeChanged: (_) async {},
            onRepeatTypeChanged: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('許可する'), findsOneWidget);
    expect(find.text('ON'), findsNothing);
  });

  testWidgets('繰り返しのみ設定済みでも統一シートを表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TaskDueDateTimeSheet(
            initialDueDate: null,
            initialReminderTime: const TimeOfDay(hour: 7, minute: 0),
            initialRepeatType: TaskRepeatType.daily,
            notificationPreferences: NotificationPreferences.defaults,
            notificationsFeatureEnabled: true,
            checkNotificationPermission: () async => true,
            onRequestNotificationPermission: () async => true,
            onDueDateChanged: (_) async {},
            onReminderTimeChanged: (_) async {},
            onRepeatTypeChanged: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('due_repeat_row')), findsOneWidget);
    expect(find.text('毎日'), findsOneWidget);
    expect(find.text('🕖 07:00'), findsOneWidget);
    expect(find.text('通知'), findsOneWidget);
  });

  test('formatReminderTimeSheet はスペース付きで表示する', () {
    expect(
      DateFormatter.formatReminderTimeSheet(const TimeOfDay(hour: 9, minute: 0)),
      '🕘 09:00',
    );
  });
}
