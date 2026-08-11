import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flowdo/config/app_features.dart';
import 'package:flowdo/models/flowdo_calendar.dart';
import 'package:flowdo/widgets/category_bar.dart';
import 'package:flowdo/widgets/task_tile.dart';

import 'flowdo_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(SharedPreferences.resetStatic);

  testWidgets('FlowDo が起動して入力欄を表示する', (WidgetTester tester) async {
    await pumpFlowDoApp(tester);

    expect(find.text('FlowDo'), findsOneWidget);
    expect(
      find.text('頭に浮かんだことを、そのまま書き出そう。'),
      findsOneWidget,
    );
    expect(find.text('改行ごとに1件のタスクになります。'), findsOneWidget);
    expect(find.text('まず全部書き出そう。整理はあとから。'), findsOneWidget);
    expect(find.text('登録'), findsOneWidget);
    expect(
      find.text(formatCalendarMonthTitle(DateTime.now())),
      findsOneWidget,
    );
    expect(find.text('📌'), findsWidgets);
    expect(find.textContaining('ジムへ19時に行く'), findsOneWidget);

    await drainFlowDoTimers(tester);
  });

  testWidgets('入力開始で入力例が消える', (WidgetTester tester) async {
    await pumpFlowDoApp(tester);

    expect(find.textContaining('ジムへ19時に行く'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('task_input_field')),
      'テスト',
    );
    await tester.pump();

    expect(find.textContaining('ジムへ19時に行く'), findsNothing);

    await drainFlowDoTimers(tester);
  });

  testWidgets('最近追加タスクでカテゴリー・優先度・期限を編集できる', (WidgetTester tester) async {
    await pumpFlowDoApp(tester);

    await tester.enterText(
      find.byKey(const ValueKey('task_input_field')),
      '編集テスト',
    );
    await tester.tap(find.text('登録'));
    await tester.pump();
    await settleAfterTaskRegistration(tester);

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

    await drainFlowDoTimers(tester);
  });

  testWidgets('無料版ではAI整理ボタンは非表示で手動整理ボタンが表示される',
      (WidgetTester tester) async {
    await pumpFlowDoApp(tester);

    await tester.enterText(
      find.byKey(const ValueKey('task_input_field')),
      '整理テスト',
    );
    await tester.tap(find.text('登録'));
    await tester.pump();
    await settleAfterTaskRegistration(tester);

    expectAiOrganizeButtonHidden();
    expectManualOrganizeButtonVisible(inboxCount: 1);
    expect(find.textContaining('追加したタスク', skipOffstage: false), findsOneWidget);
    expect(find.text('整理テスト', skipOffstage: false), findsOneWidget);

    await drainFlowDoTimers(tester);
  });

  testWidgets('登録したタスクは最近追加エリアに表示される', (WidgetTester tester) async {
    await pumpFlowDoApp(tester);

    await tester.enterText(
      find.byKey(const ValueKey('task_input_field')),
      'Inboxタスク',
    );
    await tester.tap(find.text('登録'));
    await tester.pump();
    await settleAfterTaskRegistration(tester);

    final taskFinder = find.text('Inboxタスク', skipOffstage: false);
    expect(taskFinder, findsOneWidget);
    await tester.ensureVisible(taskFinder);
    await settleFlowDoUi(tester);

    if (!kAiOrganizeEnabled) {
      expectAiOrganizeButtonHidden();
      expectManualOrganizeButtonVisible(inboxCount: 1);
    }
    expect(find.textContaining('追加したタスク', skipOffstage: false), findsOneWidget);

    await drainFlowDoTimers(tester);
  });

  testWidgets('初回登録後にInbox案内バナーを表示する', (WidgetTester tester) async {
    await pumpFlowDoApp(tester);

    expect(find.text(InboxGuidanceBanner.message), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('task_input_field')),
      '初回Inbox案内',
    );
    await tester.tap(find.text('登録'));
    await tester.pump();
    await settleAfterTaskRegistration(tester);

    expect(find.text(InboxGuidanceBanner.message), findsOneWidget);

    await drainFlowDoTimers(tester);
  });

  testWidgets('整理するボタンでInboxタスクを未完了リストへ移動する', (WidgetTester tester) async {
    await pumpFlowDoApp(
      tester,
      initialPreferences: {
        'flowdo_input_guidance_seen': true,
        'flowdo_favorite_guidance_seen': true,
      },
    );

    await tester.enterText(
      find.byKey(const ValueKey('task_input_field')),
      '整理ボタン確認',
    );
    await tester.tap(find.text('登録'));
    await tester.pump();
    await settleAfterTaskRegistration(tester);

    expect(find.textContaining('追加したタスク', skipOffstage: false), findsOneWidget);

    await organizeInboxTasks(tester, count: 1);

    expect(find.text('1件をタスクリストへ移動しました'), findsOneWidget);
    expect(find.textContaining('追加したタスク', skipOffstage: false), findsOneWidget);
    expect(find.text('整理する'), findsOneWidget);
    expect(find.text('整理ボタン確認', skipOffstage: false), findsOneWidget);

    await drainFlowDoTimers(tester);
  });

  testWidgets('カテゴリー追加後も Red Screen にならない', (WidgetTester tester) async {
    await pumpFlowDoApp(tester);
    await revealCategoryBar(tester);

    final addChip = find.byKey(const ValueKey('inbox_category_add_chip'));
    await tester.ensureVisible(addChip);
    await settleFlowDoUi(tester);
    await tester.tap(addChip);
    await tester.pump();
    await settleFlowDoUi(tester);

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '買い物',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('追加'),
      ),
    );
    await tester.pump();
    await settleAfterDialogClosed(tester);

    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('inbox_category_bar')),
        matching: find.text('買い物'),
      ),
      findsOneWidget,
    );

    await drainFlowDoTimers(tester);
  });

  testWidgets('カテゴリーフィルターに未分類は表示しない', (WidgetTester tester) async {
    await pumpFlowDoApp(tester);
    await revealPendingCategoryFilterBar(tester);

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('pending_category_filter_bar')),
        matching: find.text('未分類'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('pending_category_filter_bar')),
        matching: find.text('仕事'),
      ),
      findsOneWidget,
    );

    await drainFlowDoTimers(tester);
  });

  testWidgets('未分類に変更しても次回登録の初期値は仕事のまま', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpFlowDoApp(tester);

    await tester.enterText(
      find.byKey(const ValueKey('task_input_field')),
      '1件目',
    );
    await tester.tap(find.text('登録'));
    await tester.pump();
    await settleAfterTaskRegistration(tester);

    final firstTile = find.ancestor(
      of: find.text('1件目', skipOffstage: false),
      matching: find.byType(Dismissible),
    );
    final categoryChip = find.descendant(
      of: firstTile,
      matching: find.text('仕事'),
    );
    await tester.ensureVisible(categoryChip);
    await settleFlowDoUi(tester);
    await tester.tap(categoryChip);
    await tester.pump();
    await settleFlowDoUi(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('未分類'),
      ),
    );
    await tester.pump();
    await settleAfterDialogClosed(tester);

    expect(find.text('未分類に設定しました'), findsOneWidget);
    expect(find.textContaining('追加したタスク', skipOffstage: false), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('task_input_field')),
      '2件目',
    );
    await tester.tap(find.text('登録'));
    await tester.pump();
    await settleAfterTaskRegistration(tester);

    final secondTile = find.ancestor(
      of: find.text('2件目', skipOffstage: false),
      matching: find.byType(Dismissible),
    );
    await tester.ensureVisible(find.text('2件目', skipOffstage: false));
    await settleFlowDoUi(tester);
    expect(
      find.descendant(
        of: secondTile,
        matching: find.text('仕事', skipOffstage: false),
      ),
      findsOneWidget,
    );

    await drainFlowDoTimers(tester);
  });
}
