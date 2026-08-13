import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/models/flowdo_calendar.dart';
import 'package:flowdo/theme/app_theme.dart';
import 'package:flowdo/widgets/calendar_day_task_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Phase1-6 ミニToDo BottomSheet', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final today = DateTime(2026, 8, 13);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          backgroundColor: const Color(0xFFF2F2F7),
          body: CalendarDayTaskSheet(
            day: today,
            entries: const [
              FlowDoCalendarTaskEntry(
                taskId: 1,
                title: 'ゆうと誕プレ',
                kind: FlowDoCalendarTaskKind.important,
                categoryColorValue: 0xFFFF9500,
              ),
              FlowDoCalendarTaskEntry(
                taskId: 2,
                title: '今日のタスク',
                kind: FlowDoCalendarTaskKind.dueToday,
                reminderTime: TimeOfDay(hour: 10, minute: 30),
                categoryColorValue: 0xFF007AFF,
              ),
              FlowDoCalendarTaskEntry(
                taskId: 3,
                title: '7日以内のタスク',
                kind: FlowDoCalendarTaskKind.dueToday,
                categoryColorValue: 0xFF34C759,
              ),
            ],
            onToggleTask: (_) async {},
            isRemoving: (_) => false,
            showCompletedStyle: (_) => false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(CalendarDayTaskSheet),
      matchesGoldenFile('goldens/calendar_day_sheet_phase1_6.png'),
    );
  });
}
