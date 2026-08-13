import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/models/flowdo_calendar.dart';
import 'package:flowdo/theme/app_theme.dart';
import 'package:flowdo/widgets/calendar_day_task_sheet.dart';
import 'package:flowdo/widgets/task_completion_toggle.dart';

void main() {
  testWidgets('日付BottomSheetはセクションなしでタスクを一覧表示する',
      (WidgetTester tester) async {
    final day = DateTime(2026, 8, 13);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CalendarDayTaskSheet(
            day: day,
            entries: [
              FlowDoCalendarTaskEntry(
                taskId: 1,
                title: 'ゆうと誕プレ',
                kind: FlowDoCalendarTaskKind.important,
              ),
              FlowDoCalendarTaskEntry(
                taskId: 2,
                title: '打ち合わせ',
                kind: FlowDoCalendarTaskKind.dueToday,
                dueDate: day,
                reminderTime: const TimeOfDay(hour: 12, minute: 0),
              ),
            ],
            onToggleTask: (_) async {},
            isRemoving: (_) => false,
            showCompletedStyle: (_) => false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('8月13日（木）'), findsOneWidget);
    expect(find.text('ゆうと誕プレ'), findsOneWidget);
    expect(find.text('打ち合わせ'), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget);
    expect(find.textContaining('今日'), findsNothing);
    expect(find.textContaining('7日以内'), findsNothing);
    expect(find.textContaining('固定'), findsNothing);
    expect(find.byType(TaskCompletionToggle), findsNWidgets(2));
  });
}
