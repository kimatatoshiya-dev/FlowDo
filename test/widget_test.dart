import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flowdo/main.dart';
import 'package:flowdo/services/analytics/noop_analytics_service.dart';
import 'package:flowdo/services/auth/noop_auth_service.dart';
import 'package:flowdo/widgets/category_bar.dart';

void main() {
  const analyticsService = NoOpAnalyticsService();
  const authService = NoOpAuthService();

  testWidgets('FlowDo が起動して入力欄を表示する', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const FlowDoApp(
        analyticsService: analyticsService,
        authService: authService,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FlowDo'), findsOneWidget);
    expect(
      find.text('頭に浮かんだことを、そのまま書き出そう。'),
      findsOneWidget,
    );
    expect(find.text('改行ごとに1件のタスクになります。'), findsOneWidget);
    expect(find.text('まず全部書き出そう。整理はあとから。'), findsOneWidget);
    expect(find.text('登録'), findsOneWidget);
    expect(find.text('未完了'), findsOneWidget);
    expect(find.text('今日の期限'), findsOneWidget);
    expect(find.textContaining('ジムへ19時に行く'), findsOneWidget);
  });

  testWidgets('入力開始で入力例が消える', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const FlowDoApp(analyticsService: NoOpAnalyticsService(), authService: NoOpAuthService()));
    await tester.pumpAndSettle();

    expect(find.textContaining('ジムへ19時に行く'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('task_input_field')),
      'テスト',
    );
    await tester.pump();

    expect(find.textContaining('ジムへ19時に行く'), findsNothing);
  });

  testWidgets('最近追加タスクでカテゴリー・優先度・期限を編集できる', (WidgetTester tester) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const FlowDoApp(analyticsService: NoOpAnalyticsService(), authService: NoOpAuthService()));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        break;
      }
    }
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('task_input_field')),
      '編集テスト',
    );
    await tester.tap(find.text('登録'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final taskTile = find.ancestor(
      of: find.text('編集テスト', skipOffstage: false),
      matching: find.byType(Dismissible),
    );
    expect(
      find.descendant(of: taskTile, matching: find.text('仕事')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: taskTile, matching: find.text('☆なし')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: taskTile, matching: find.text('期限なし')),
      findsOneWidget,
    );
  });

  testWidgets('整理後は最近追加エリアが空になり整理ボタンが消える', (WidgetTester tester) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const FlowDoApp(analyticsService: NoOpAnalyticsService(), authService: NoOpAuthService()));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        break;
      }
    }
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('task_input_field')),
      '整理テスト',
    );
    await tester.tap(find.text('登録'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('整理する'), findsOneWidget);
    expect(find.textContaining('追加したタスク', skipOffstage: false), findsOneWidget);

    await tester.ensureVisible(find.text('整理する'));
    await tester.tap(find.text('整理する'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    expect(find.text('整理する'), findsNothing);
    expect(find.textContaining('追加したタスク', skipOffstage: false), findsNothing);
    expect(find.text('整理テスト', skipOffstage: false), findsOneWidget);
  });

  testWidgets('登録したタスクは最近追加エリアに表示される', (WidgetTester tester) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const FlowDoApp(analyticsService: NoOpAnalyticsService(), authService: NoOpAuthService()));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        break;
      }
    }
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('task_input_field')),
      'Inboxタスク',
    );
    await tester.tap(find.text('登録'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final taskFinder = find.text('Inboxタスク', skipOffstage: false);
    expect(taskFinder, findsOneWidget);
    await tester.ensureVisible(taskFinder);
    await tester.pumpAndSettle();

    expect(find.text('整理する'), findsOneWidget);
    expect(find.textContaining('追加したタスク', skipOffstage: false), findsOneWidget);
  });

  testWidgets('カテゴリー追加後も Red Screen にならない', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const FlowDoApp(analyticsService: NoOpAnalyticsService(), authService: NoOpAuthService()));
    await tester.pumpAndSettle();

    final addChip = find.byKey(const ValueKey('category_add_chip'));
    await tester.ensureVisible(addChip);
    await tester.pumpAndSettle();
    await tester.tap(addChip);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '買い物',
    );
    await tester.tap(find.text('追加'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('買い物'), findsOneWidget);
  });

  testWidgets('カテゴリーフィルターに未分類は表示しない', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const FlowDoApp(analyticsService: NoOpAnalyticsService(), authService: NoOpAuthService()));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(CategoryBar),
        matching: find.text('未分類'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(CategoryBar),
        matching: find.text('仕事'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('未分類に変更しても次回登録の初期値は仕事のまま', (WidgetTester tester) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const FlowDoApp(analyticsService: NoOpAnalyticsService(), authService: NoOpAuthService()));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        break;
      }
    }
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('task_input_field')),
      '1件目',
    );
    await tester.tap(find.text('登録'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final firstTile = find.ancestor(
      of: find.text('1件目', skipOffstage: false),
      matching: find.byType(Dismissible),
    );
    await tester.tap(
      find.descendant(of: firstTile, matching: find.text('仕事')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: firstTile, matching: find.text('未分類')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('task_input_field')),
      '2件目',
    );
    await tester.tap(find.text('登録'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final secondTile = find.ancestor(
      of: find.text('2件目', skipOffstage: false),
      matching: find.byType(Dismissible),
    );
    expect(
      find.descendant(of: secondTile, matching: find.text('仕事')),
      findsOneWidget,
    );
  });
}
