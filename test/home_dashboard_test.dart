import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/models/category_item.dart';
import 'package:flowdo/models/flowdo_calendar.dart';
import 'package:flowdo/models/task.dart';
import 'package:flowdo/models/today_focus.dart';
import 'package:flowdo/theme/app_theme.dart';
import 'package:flowdo/widgets/calendar_day_task_sheet.dart';
import 'package:flowdo/widgets/home_dashboard.dart';
import 'package:flowdo/widgets/task_completion_toggle.dart';
import 'package:flowdo/widgets/today_focus_task_sheet.dart';

FlowDoCalendarMonthData sampleCalendarData({DateTime? today}) {
  final referenceToday = today ?? DateTime(2026, 8, 11);
  return buildFlowDoCalendarMonth(
    tasks: [
      Task(
        id: 1,
        title: '重要',
        isInbox: false,
        isFavorite: true,
      ),
      Task(
        id: 2,
        title: '今日',
        isInbox: false,
        dueDate: referenceToday,
      ),
      Task(
        id: 3,
        title: '予定',
        isInbox: false,
        dueDate: DateTime(referenceToday.year, referenceToday.month, 20),
      ),
    ],
    today: referenceToday,
  );
}

List<TodayFocusSectionData> sampleTodayFocusSections() {
  return const [
    TodayFocusSectionData(
      kind: TodayFocusFilterKind.important,
      label: '重要',
      tasks: [
        TodayFocusTaskItem(taskId: 1, title: '重要タスク', categoryName: '仕事'),
      ],
    ),
    TodayFocusSectionData(
      kind: TodayFocusFilterKind.dueToday,
      label: '今日期限',
      tasks: [
        TodayFocusTaskItem(taskId: 2, title: '今日タスク', categoryName: '仕事'),
      ],
    ),
    TodayFocusSectionData(
      kind: TodayFocusFilterKind.dueWithin7Days,
      label: '7日以内',
      tasks: [
        TodayFocusTaskItem(taskId: 3, title: '7日タスク', categoryName: '仕事'),
      ],
    ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('1ページ目に月間カレンダーとサマリーを表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HomeDashboard(
            calendarData: sampleCalendarData(),
            categoryCounts: const [],
            onCalendarDayTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('2026年8月'), findsOneWidget);
    expect(find.text('📌'), findsWidgets);
    expect(find.text('🔥'), findsWidgets);
    expect(find.text('📅'), findsWidgets);
    expect(find.text('日'), findsOneWidget);
    expect(find.text('土'), findsOneWidget);
    expect(find.text('今日やること'), findsNothing);
    expect(find.text('▶ 重要タスク一覧'), findsNothing);
  });

  testWidgets('日付タップでコールバックが呼ばれる', (WidgetTester tester) async {
    DateTime? tappedDay;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HomeDashboard(
            calendarData: sampleCalendarData(),
            categoryCounts: const [],
            onCalendarDayTap: (day) => tappedDay = day,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('11').first);
    await tester.pump();

    expect(tappedDay, DateTime(2026, 8, 11));
  });

  testWidgets('CalendarDayTaskSheet に完了トグル付き一覧を表示する',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CalendarDayTaskSheet(
            day: DateTime(2026, 8, 11),
            entries: const [
              FlowDoCalendarTaskEntry(
                taskId: 1,
                title: '重要タスク',
                kind: FlowDoCalendarTaskKind.important,
              ),
              FlowDoCalendarTaskEntry(
                taskId: 2,
                title: '今日タスク',
                kind: FlowDoCalendarTaskKind.dueToday,
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

    expect(find.text('8月11日（火）'), findsOneWidget);
    expect(find.text('残り 2件'), findsOneWidget);
    expect(find.text('重要タスク'), findsOneWidget);
    expect(find.text('今日タスク'), findsOneWidget);
    expect(find.byType(TaskCompletionToggle), findsNWidgets(2));
  });

  testWidgets('2ページ目にカテゴリー別件数を表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HomeDashboard(
            calendarData: sampleCalendarData(),
            categoryCounts: [
              CategoryIncompleteCount(
                category: CategoryItem.defaults()[1],
                count: 18,
              ),
            ],
            onCalendarDayTap: (_) {},
          ),
        ),
      ),
    );

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('カテゴリー別'), findsOneWidget);
    expect(find.text('仕事'), findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('仕事'),
          matching: find.byType(Row),
        ),
        matching: find.text('18'),
      ),
      findsOneWidget,
    );
  });

  test('categoryEmoji はカテゴリー名に応じた絵文字を返す', () {
    expect(categoryEmoji(CategoryItem.defaults()[1]), '📁');
    expect(
      categoryEmoji(CategoryItem.create(name: '買い物', colorValue: 0xFFFF9500)),
      '🛒',
    );
  });

  test('flattenTodayFocusSections は区分付きフラット一覧を返す', () {
    final entries = flattenTodayFocusSections(sampleTodayFocusSections());

    expect(entries, hasLength(3));
    expect(entries.first.kind, TodayFocusFilterKind.important);
  });
}
