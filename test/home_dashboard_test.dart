import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/models/category_item.dart';
import 'package:flowdo/models/flowdo_calendar.dart';
import 'package:flowdo/models/task.dart';
import 'package:flowdo/models/today_focus.dart';
import 'package:flowdo/theme/app_theme.dart';
import 'package:flowdo/utils/japanese_holidays.dart';
import 'package:flowdo/widgets/calendar_day_task_sheet.dart';
import 'package:flowdo/widgets/home_dashboard.dart';
import 'package:flowdo/widgets/task_completion_toggle.dart';
import 'package:flowdo/widgets/today_focus_task_sheet.dart';

List<Task> sampleTasks({DateTime? today}) {
  final referenceToday = today ?? DateTime(2026, 8, 11);
  return [
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
  ];
}

FlowDoCalendarMonthData sampleCalendarData({DateTime? today}) {
  final referenceToday = today ?? DateTime(2026, 8, 11);
  return buildFlowDoCalendarMonth(
    tasks: sampleTasks(today: referenceToday),
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
            tasks: sampleTasks(),
            today: DateTime(2026, 8, 11),
            onCalendarDayTap: (_, __) {},
            onOpenTodayFocusSheet: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('2026年8月'), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar_prev_month')), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar_next_month')), findsOneWidget);
    expect(find.byKey(const ValueKey('dashboard_summary_today')), findsOneWidget);
    expect(find.byKey(const ValueKey('dashboard_summary_within7days')), findsOneWidget);
    expect(find.text('今日'), findsOneWidget);
    expect(find.text('7日以内'), findsOneWidget);
    expect(find.text('🗓️'), findsWidgets);
    expect(find.text('🔥'), findsWidgets);
    expect(find.text('日'), findsOneWidget);
    expect(find.text('土'), findsOneWidget);
    expect(find.text('今日やること'), findsNothing);
    expect(find.text('▶ 重要タスク一覧'), findsOneWidget);
  });

  testWidgets('今日・今週カードタップでコールバックが呼ばれる', (WidgetTester tester) async {
    var todayTapped = false;
    var weekTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HomeDashboard(
            tasks: sampleTasks(),
            today: DateTime(2026, 8, 11),
            onCalendarDayTap: (_, __) {},
            onOpenTodayFocusSheet: () {},
            onTodaySummaryTap: () => todayTapped = true,
            onWeekSummaryTap: () => weekTapped = true,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('dashboard_summary_today')));
    await tester.pump();
    expect(todayTapped, isTrue);

    await tester.tap(find.byKey(const ValueKey('dashboard_summary_within7days')));
    await tester.pump();
    expect(weekTapped, isTrue);
  });

  testWidgets('月切り替えで前月・翌月を表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HomeDashboard(
            tasks: sampleTasks(),
            today: DateTime(2026, 8, 11),
            onCalendarDayTap: (_, __) {},
            onOpenTodayFocusSheet: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('calendar_next_month')));
    await tester.pump();
    expect(find.text('2026年9月'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('calendar_prev_month')));
    await tester.pump();
    expect(find.text('2026年8月'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('calendar_prev_month')));
    await tester.pump();
    expect(find.text('2026年7月'), findsOneWidget);
  });

  testWidgets('曜日ラベルに日曜=赤・土曜=青を適用する', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HomeDashboard(
            tasks: sampleTasks(),
            today: DateTime(2026, 8, 11),
            onCalendarDayTap: (_, __) {},
            onOpenTodayFocusSheet: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    final sundayLabel = tester.widget<Text>(find.text('日'));
    final saturdayLabel = tester.widget<Text>(find.text('土'));
    final mondayLabel = tester.widget<Text>(find.text('月'));

    expect(sundayLabel.style?.color, calendarSundayColor);
    expect(saturdayLabel.style?.color, calendarSaturdayColor);
    expect(mondayLabel.style?.color, isNot(calendarSundayColor));
    expect(mondayLabel.style?.color, isNot(calendarSaturdayColor));
  });

  testWidgets('重要タスク一覧ボタンでコールバックが呼ばれる', (WidgetTester tester) async {
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HomeDashboard(
            tasks: sampleTasks(),
            today: DateTime(2026, 8, 11),
            onCalendarDayTap: (_, __) {},
            onOpenTodayFocusSheet: () => opened = true,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('▶ 重要タスク一覧'));
    await tester.pump();

    expect(opened, isTrue);
  });

  testWidgets('日付タップでコールバックが呼ばれる', (WidgetTester tester) async {
    DateTime? tappedDay;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HomeDashboard(
            tasks: sampleTasks(),
            today: DateTime(2026, 8, 11),
            onCalendarDayTap: (day, _) => tappedDay = day,
            onOpenTodayFocusSheet: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('11').first);
    await tester.pump();

    expect(tappedDay, DateTime(2026, 8, 11));
  });

  testWidgets('カレンダー日付タップで当日の全タスクを BottomSheet 表示する', (
    WidgetTester tester,
  ) async {
    final today = DateTime(2026, 8, 13);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HomeDashboard(
            tasks: [
              Task(
                id: 1,
                title: 'ゆうと誕プレ',
                isInbox: false,
                isFavorite: true,
              ),
              Task(
                id: 2,
                title: '今日のタスク',
                isInbox: false,
                dueDate: today,
              ),
              Task(
                id: 3,
                title: '7日以内のタスク',
                isInbox: false,
                dueDate: today,
              ),
            ],
            today: today,
            onCalendarDayTap: (day, referenceToday) async {
              await CalendarDayTaskSheet.show(
                tester.element(find.byType(HomeDashboard)),
                day: day,
                entries: calendarTasksForDay(
                  tasks: [
                    Task(
                      id: 1,
                      title: 'ゆうと誕プレ',
                      isInbox: false,
                      isFavorite: true,
                    ),
                    Task(
                      id: 2,
                      title: '今日のタスク',
                      isInbox: false,
                      dueDate: today,
                    ),
                    Task(
                      id: 3,
                      title: '7日以内のタスク',
                      isInbox: false,
                      dueDate: today,
                    ),
                  ],
                  day: day,
                  today: referenceToday,
                ),
                onToggleTask: (_) async {},
                isRemoving: (_) => false,
                showCompletedStyle: (_) => false,
              );
            },
            onOpenTodayFocusSheet: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('13').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('8月13日（木）'), findsOneWidget);
    expect(find.text('ゆうと誕プレ'), findsOneWidget);
    expect(find.text('今日のタスク'), findsOneWidget);
    expect(find.text('7日以内のタスク'), findsOneWidget);
    expect(find.textContaining('固定'), findsNothing);
    expect(find.textContaining('今日 1件'), findsNothing);
  });

  testWidgets('CalendarDayTaskSheet に完了トグル付き一覧を表示する',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CalendarDayTaskSheet(
            day: DateTime(2026, 8, 11),
            entries: [
              FlowDoCalendarTaskEntry(
                taskId: 1,
                title: '重要タスク',
                kind: FlowDoCalendarTaskKind.important,
              ),
              FlowDoCalendarTaskEntry(
                taskId: 2,
                title: '今日タスク',
                kind: FlowDoCalendarTaskKind.dueToday,
                dueDate: DateTime(2026, 8, 11),
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
    expect(find.text('重要タスク'), findsOneWidget);
    expect(find.text('今日タスク'), findsOneWidget);
    expect(find.textContaining('固定'), findsNothing);
    expect(find.textContaining('今日 1件'), findsNothing);
    expect(find.byType(TaskCompletionToggle), findsNWidgets(2));
  });

  testWidgets('2ページ目にホームダッシュボードを表示する', (WidgetTester tester) async {
    var todayPageOpened = false;
    var importantTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HomeDashboard(
            tasks: sampleTasks(),
            today: DateTime(2026, 8, 11),
            todayMemoText: '郵便局\nコピー',
            onCalendarDayTap: (_, __) {},
            onOpenTodayFocusSheet: () {},
            onOpenTodayPage: () => todayPageOpened = true,
            onImportantSummaryTap: () => importantTapped = true,
          ),
        ),
      ),
    );

    await tester.drag(find.byType(PageView), const Offset(-800, 0));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('dashboard_weather_card')), findsOneWidget);
    expect(find.text('東京'), findsOneWidget);
    expect(find.text('31℃'), findsOneWidget);
    expect(find.text('降水確率 10%'), findsOneWidget);
    expect(find.byKey(const ValueKey('dashboard_stat_today')), findsOneWidget);
    expect(find.byKey(const ValueKey('dashboard_stat_important')), findsOneWidget);
    expect(find.byKey(const ValueKey('dashboard_stat_within7days')), findsOneWidget);
    expect(find.byKey(const ValueKey('dashboard_stat_routine')), findsOneWidget);
    expect(find.text('1件'), findsNWidgets(3));
    expect(find.text('0 / 0'), findsOneWidget);
    expect(find.text('今日の達成率'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('12日'), findsOneWidget);
    expect(find.byKey(const ValueKey('dashboard_memo_card')), findsOneWidget);
    expect(find.textContaining('郵便局'), findsOneWidget);
    expect(find.textContaining('コピー'), findsOneWidget);
    expect(find.text('📊 ダッシュボード'), findsNothing);
    expect(find.text('カテゴリー'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('dashboard_stat_important')));
    await tester.pump();
    expect(importantTapped, isTrue);

    await tester.tap(find.byKey(const ValueKey('dashboard_stat_routine')));
    await tester.pump();
    expect(todayPageOpened, isTrue);
  });

  test('categoryEmoji はカテゴリー名に応じた絵文字を返す', () {
    expect(categoryEmoji(CategoryItem.defaults()[1]), '💼');
    expect(
      categoryEmoji(CategoryItem.create(name: '買い物', colorValue: 0xFFFF9500)),
      '🛒',
    );
    expect(
      categoryEmoji(CategoryItem.create(name: '趣味', colorValue: 0xFF5856D6)),
      '🎨',
    );
    expect(
      categoryEmoji(CategoryItem.create(name: 'FlowDo', colorValue: 0xFF34C759)),
      '💡',
    );
  });

  test('flattenTodayFocusSections は区分付きフラット一覧を返す', () {
    final entries = flattenTodayFocusSections(sampleTodayFocusSections());

    expect(entries, hasLength(3));
    expect(entries.first.kind, TodayFocusFilterKind.important);
  });

  test('calendarDayNumberColor は今日を優先する', () {
    final today = DateTime(2026, 8, 11);
    expect(
      calendarDayNumberColor(
        day: today,
        isToday: true,
        standardColor: Colors.black,
      ),
      Colors.white,
    );
  });

  test('calendarDayNumberColor は祝日を赤にする', () {
    final holiday = DateTime(2026, 1, 1);
    expect(isJapaneseHoliday(holiday), isTrue);
    expect(
      calendarDayNumberColor(
        day: holiday,
        isToday: false,
        standardColor: Colors.black,
      ),
      calendarSundayColor,
    );
  });
}
