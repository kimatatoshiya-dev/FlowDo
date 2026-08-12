import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
            onDueDateChanged: (_) async {},
            onReminderTimeChanged: (_) async {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('due_date_empty_row')), findsOneWidget);
    expect(find.text(DateFormatter.noDueDateLabel), findsOneWidget);
  });

  testWidgets('期限設定済みは日付と時間をまとめて表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TaskDueDateTimeSheet(
            initialDueDate: DateTime(2026, 8, 17),
            initialReminderTime: const TimeOfDay(hour: 9, minute: 0),
            onDueDateChanged: (_) async {},
            onReminderTimeChanged: (_) async {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('2026/08/17'), findsOneWidget);
    expect(find.text('🕘 09:00'), findsOneWidget);
    expect(find.text('通知'), findsOneWidget);
    expect(find.textContaining('準備中'), findsOneWidget);
  });

  test('formatReminderTimeSheet はスペース付きで表示する', () {
    expect(
      DateFormatter.formatReminderTimeSheet(const TimeOfDay(hour: 9, minute: 0)),
      '🕘 09:00',
    );
  });
}
