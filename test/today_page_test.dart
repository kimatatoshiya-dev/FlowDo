import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/models/task.dart';
import 'package:flowdo/models/task_repeat_type.dart';
import 'package:flowdo/screens/today_page.dart';
import 'package:flowdo/theme/app_theme.dart';
import 'package:flowdo/widgets/task_completion_toggle.dart';

import 'flowdo_test_helpers.dart';

void main() {
  final today = DateTime(2026, 8, 13);

  Task sampleTask({
    required int id,
    required String title,
    bool isCompleted = false,
    bool isFavorite = false,
    TaskRepeatType repeatType = TaskRepeatType.none,
    DateTime? dueDate,
    DateTime? completedAt,
    TimeOfDay? reminderTime,
  }) {
    return Task(
      id: id,
      title: title,
      isInbox: false,
      isCompleted: isCompleted,
      isFavorite: isFavorite,
      repeatType: repeatType,
      dueDate: dueDate,
      completedAt: completedAt,
      reminderTime: reminderTime,
    );
  }

  group('TodayGreeting.resolve', () {
    test('5:00〜10:59 は朝の挨拶', () {
      final greeting = TodayGreeting.resolve(DateTime(2026, 8, 13, 8, 30));
      expect(greeting.headline, '🌅 おはようございます！');
      expect(greeting.message, '今日も一歩ずつ進めていきましょう。');
    });

    test('11:00〜16:59 は昼の挨拶', () {
      final greeting = TodayGreeting.resolve(DateTime(2026, 8, 13, 14, 0));
      expect(greeting.headline, '☀️ こんにちは！');
      expect(greeting.message, '今日の予定、順調ですか？');
    });
  });

  group('todayScheduleTasks', () {
    test('今日期限の未完了タスクを時間順に返す', () {
      final result = todayScheduleTasks(
        tasks: [
          sampleTask(
            id: 1,
            title: '会議',
            dueDate: today,
            reminderTime: const TimeOfDay(hour: 9, minute: 0),
          ),
          sampleTask(
            id: 2,
            title: 'ゆうと誕プレ',
            dueDate: today,
            reminderTime: const TimeOfDay(hour: 12, minute: 0),
          ),
          sampleTask(id: 3, title: '時間なし', dueDate: today),
          sampleTask(
            id: 4,
            title: '完了済み',
            dueDate: today,
            isCompleted: true,
          ),
          sampleTask(id: 5, title: '明日', dueDate: DateTime(2026, 8, 14)),
        ],
        referenceToday: today,
      );

      expect(result.map((entry) => entry.title), [
        '会議',
        'ゆうと誕プレ',
        '時間なし',
      ]);
    });
  });

  group('todayTopPriorityTask', () {
    test('今日期限かつ重要な未完了タスクを1件返す', () {
      final result = todayTopPriorityTask(
        tasks: [
          sampleTask(id: 1, title: '通常', dueDate: today),
          sampleTask(
            id: 2,
            title: '最重要',
            dueDate: today,
            isFavorite: true,
          ),
          sampleTask(
            id: 3,
            title: '明日重要',
            dueDate: DateTime(2026, 8, 14),
            isFavorite: true,
          ),
        ],
        referenceToday: today,
      );

      expect(result?.title, '最重要');
    });

    test('該当なしのとき null', () {
      expect(
        todayTopPriorityTask(
          tasks: [sampleTask(id: 1, title: '通常', dueDate: today)],
          referenceToday: today,
        ),
        isNull,
      );
    });
  });

  group('todayWithin7DaysTasks', () {
    test('明日〜7日後の未完了タスクを返す', () {
      final result = todayWithin7DaysTasks(
        tasks: [
          sampleTask(id: 1, title: '今日', dueDate: today),
          sampleTask(id: 2, title: '明日', dueDate: DateTime(2026, 8, 14)),
          sampleTask(id: 3, title: '7日後', dueDate: DateTime(2026, 8, 20)),
          sampleTask(id: 4, title: '8日後', dueDate: DateTime(2026, 8, 21)),
        ],
        referenceToday: today,
      );

      expect(result.map((task) => task.title), ['明日', '7日後']);
      expect(todayDaysUntilDue(result.first, today), 1);
      expect(todayDaysUntilDue(result.last, today), 7);
    });
  });

  group('todayAchievementStats', () {
    test('今日期限タスクの達成率を計算する', () {
      final stats = todayAchievementStats(
        tasks: [
          sampleTask(id: 1, title: '完了', dueDate: today, isCompleted: true),
          sampleTask(id: 2, title: '未完了', dueDate: today),
          sampleTask(id: 3, title: '明日', dueDate: DateTime(2026, 8, 14)),
        ],
        referenceToday: today,
      );

      expect(stats.completedCount, 1);
      expect(stats.totalCount, 2);
      expect(stats.percent, 50);
    });

    test('対象なしのとき 0%', () {
      final stats = todayAchievementStats(tasks: const [], referenceToday: today);
      expect(stats.percent, 0);
    });
  });

  testWidgets('TodayPage に実データセクションを表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: TodayPage(
          now: DateTime(2026, 8, 13, 14, 0),
          tasks: [
            sampleTask(
              id: 1,
              title: '最重要タスク',
              dueDate: today,
              isFavorite: true,
            ),
            sampleTask(
              id: 2,
              title: '会議',
              dueDate: today,
              reminderTime: const TimeOfDay(hour: 9, minute: 0),
            ),
            sampleTask(
              id: 3,
              title: '打ち合わせ',
              dueDate: today,
              reminderTime: const TimeOfDay(hour: 15, minute: 0),
              isCompleted: true,
            ),
            sampleTask(id: 4, title: 'りんぴ協賛', dueDate: DateTime(2026, 8, 16)),
            sampleTask(
              id: 5,
              title: '水やり',
              repeatType: TaskRepeatType.daily,
            ),
            sampleTask(
              id: 6,
              title: 'ストレッチ',
              repeatType: TaskRepeatType.daily,
              isCompleted: true,
              completedAt: DateTime(2026, 8, 13, 8, 0),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('最重要タスク'), findsWidgets);
    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('会議'), findsOneWidget);
    expect(find.text('打ち合わせ'), findsNothing);
    expect(find.text('あと3日'), findsOneWidget);
    expect(find.text('33%'), findsOneWidget);
    expect(find.text('水やり'), findsOneWidget);
    expect(find.text('ストレッチ'), findsOneWidget);
    expect(find.byType(TaskCompletionToggle), findsWidgets);
  });

  testWidgets('該当なしのときプレースホルダーを表示する',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: TodayPage(now: DateTime(2026, 8, 13, 14, 0)),
      ),
    );
    await tester.pump();

    expect(find.text('今日の最重要はありません'), findsOneWidget);
    expect(find.text('今日の予定はありません'), findsOneWidget);
    expect(find.text('7日以内のタスクはありません'), findsOneWidget);
    expect(find.text('ルーティンはありません'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
  });

  testWidgets('今日メモを編集すると自動保存コールバックが呼ばれる',
      (WidgetTester tester) async {
    var savedText = '';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: TodayPage(
          now: today,
          memoText: '',
          onMemoChanged: (text) async {
            savedText = text;
          },
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('daily_memo_field')),
      '振り返り',
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(savedText, '振り返り');
  });

  testWidgets('ホーム PageView に Today 画面が組み込まれている',
      (WidgetTester tester) async {
    await pumpFlowDoApp(tester);
    await settleFlowDoUi(tester);

    expect(find.byKey(const ValueKey('flowdo_home_page_view')), findsOneWidget);

    await tester.fling(
      find.byKey(const ValueKey('flowdo_home_page_view')),
      const Offset(-3000, 0),
      4000,
    );
    await tester.pumpAndSettle();

    expect(find.text('今日の達成率'), findsOneWidget);
    expect(find.byKey(const ValueKey('flowdo_today_page')), findsOneWidget);
  });
}
