import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/models/category_item.dart';
import 'package:flowdo/models/today_focus.dart';
import 'package:flowdo/theme/app_theme.dart';
import 'package:flowdo/widgets/flowdo_icons.dart';
import 'package:flowdo/widgets/home_dashboard.dart';
import 'package:flowdo/widgets/task_completion_toggle.dart';
import 'package:flowdo/widgets/today_focus_task_sheet.dart';

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

  testWidgets('1ページ目に今日やることの指標を表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HomeDashboard(
            pinnedCount: 2,
            dueTodayCount: 3,
            dueWithin7DaysCount: 5,
            categoryCounts: const [],
            onOpenTodayFocusSheet: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('今日やること'), findsOneWidget);
    expect(find.text('重要'), findsOneWidget);
    expect(find.text('固定'), findsNothing);
    expect(find.text('今日期限'), findsOneWidget);
    expect(find.text('7日以内'), findsOneWidget);
    expect(find.text('▶ 重要タスク一覧'), findsOneWidget);
    expect(find.byType(FlowDoCalendar7Icon), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text('3'), findsWidgets);
    expect(find.text('5'), findsWidgets);
    expect(find.text('完了率'), findsNothing);
  });

  testWidgets('重要タスク一覧ボタンでコールバックが呼ばれる', (WidgetTester tester) async {
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HomeDashboard(
            pinnedCount: 1,
            dueTodayCount: 0,
            dueWithin7DaysCount: 0,
            categoryCounts: const [],
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

  testWidgets('TodayFocusTaskSheet に完了トグル付き一覧を表示する',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TodayFocusTaskSheet(
            sections: sampleTodayFocusSections(),
            onToggleTask: (_) async {},
            isRemoving: (_) => false,
            showCompletedStyle: (_) => false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('重要＆期限が近いタスク'), findsOneWidget);
    expect(find.text(TodayFocusTaskSheet.subtitle), findsOneWidget);
    expect(find.text('残り 3件'), findsOneWidget);
    expect(find.text('重要タスク'), findsOneWidget);
    expect(find.text('今日タスク'), findsOneWidget);
    expect(find.text('7日タスク'), findsOneWidget);
    expect(find.byType(TaskCompletionToggle), findsNWidgets(3));
    expect(find.byType(FlowDoCalendar7Icon), findsOneWidget);
  });

  testWidgets('FlowDoCalendar7Icon はSVGアセットを読み込む', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: FlowDoCalendar7Icon(size: 20),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.bySemanticsLabel('7日以内'), findsOneWidget);
  });

  testWidgets('2ページ目にカテゴリー別件数を表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HomeDashboard(
            pinnedCount: 0,
            dueTodayCount: 0,
            dueWithin7DaysCount: 0,
            categoryCounts: [
              CategoryIncompleteCount(
                category: CategoryItem.defaults()[1],
                count: 18,
              ),
            ],
            onOpenTodayFocusSheet: () {},
          ),
        ),
      ),
    );

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('カテゴリー別'), findsOneWidget);
    expect(find.text('仕事'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
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
    expect(entries[0].kind, TodayFocusFilterKind.important);
    expect(entries[0].task.title, '重要タスク');
    expect(entries[1].kind, TodayFocusFilterKind.dueToday);
    expect(entries[2].kind, TodayFocusFilterKind.dueWithin7Days);
  });

  test('countRemainingTodayFocusTasks は未完了の残件数を返す', () {
    final entries = flattenTodayFocusSections(sampleTodayFocusSections());

    expect(
      countRemainingTodayFocusTasks(
        entries,
        showCompletedStyle: (_) => false,
        isRemoving: (_) => false,
      ),
      3,
    );
    expect(
      countRemainingTodayFocusTasks(
        entries,
        showCompletedStyle: (id) => id == 1,
        isRemoving: (_) => false,
      ),
      2,
    );
  });
}
