import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flowdo/widgets/category_bar.dart';
import 'package:flowdo/widgets/task_swipe_actions.dart';
import 'package:flowdo/widgets/task_tile.dart';

import 'flowdo_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(SharedPreferences.resetStatic);

  Future<void> registerInboxTask(WidgetTester tester, String title) async {
    await tester.enterText(
      find.byKey(const ValueKey('task_input_field')),
      title,
    );
    await tester.tap(find.text('登録'));
    await tester.pump();
    await settleAfterTaskRegistration(tester);
    await settleFlowDoUi(tester);
  }

  Finder inboxTaskTile(String title) {
    return taskTileForTitle(title);
  }

  testWidgets('Inboxタスクのカテゴリ変更後もInboxに残る', (WidgetTester tester) async {
    await pumpFlowDoApp(tester);
    await registerInboxTask(tester, '設定テスト');

    expect(find.textContaining('追加したタスク', skipOffstage: false), findsOneWidget);
    expectManualOrganizeButtonVisible(inboxCount: 1);

    final categoryDot = find.descendant(
      of: inboxTaskTile('設定テスト'),
      matching: find.byKey(TaskTile.categoryColorDotKey),
    );
    await tester.ensureVisible(categoryDot);
    await settleFlowDoUi(tester);
    await tester.tap(categoryDot);
    await tester.pump();
    await settleFlowDoUi(tester);

    expect(find.text('グループを選択'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('仕事'),
      ),
    );
    await tester.pump();
    await settleAfterDialogClosed(tester);

    expect(find.text('仕事に設定しました'), findsOneWidget);
    expect(find.text('リストへ移動中…'), findsNothing);
    expect(find.textContaining('追加したタスク', skipOffstage: false), findsOneWidget);

    await drainFlowDoTimers(tester);
  });

  testWidgets('Inboxで📌を設定してもInboxに残る', (WidgetTester tester) async {
    await pumpFlowDoApp(tester);
    await registerInboxTask(tester, '重要テスト');

    expect(find.textContaining('追加したタスク', skipOffstage: false), findsOneWidget);

    final pinButton = find.descendant(
      of: inboxTaskTile('重要テスト'),
      matching: find.byTooltip('最上位へ固定'),
    );
    await tester.ensureVisible(pinButton);
    await settleFlowDoUi(tester);
    await tester.tap(pinButton);
    await tester.pump();
    await settleFlowDoUi(tester);

    expect(find.text('📌 重要に設定しました'), findsOneWidget);
    expect(find.textContaining('追加したタスク', skipOffstage: false), findsOneWidget);
    expect(find.text('1件を整理する'), findsOneWidget);

    await drainFlowDoTimers(tester);
  });

  testWidgets('Inboxのグループバーで選択したグループがタスクに反映される',
      (WidgetTester tester) async {
    await pumpFlowDoApp(tester);
    await registerInboxTask(tester, 'グループ反映');

    await revealCategoryBar(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('inbox_category_bar')),
        matching: find.text('仕事'),
      ),
    );
    await tester.pump();
    await settleFlowDoUi(tester);

    expect(find.text('仕事に設定しました'), findsOneWidget);
    expect(
      find.descendant(
        of: inboxTaskTile('グループ反映'),
        matching: find.byKey(TaskTile.categoryColorDotKey),
      ),
      findsOneWidget,
    );

    await drainFlowDoTimers(tester);
  });

  testWidgets('整理するボタンでInboxタスクが未完了リストへ移動する',
      (WidgetTester tester) async {
    await pumpFlowDoApp(tester);
    await registerInboxTask(tester, '整理テスト');

    await organizeInboxTasks(tester, count: 1);

    expect(find.text('1件をタスクリストへ移動しました'), findsOneWidget);
    expect(find.textContaining('追加したタスク', skipOffstage: false), findsOneWidget);
    expect(find.text('整理する'), findsNothing);

    final taskFinder = find.text('整理テスト', skipOffstage: false);
    await tester.ensureVisible(taskFinder);
    expect(taskFinder, findsOneWidget);

    await drainFlowDoTimers(tester);
  });

  testWidgets('Inboxタスクの右スワイプでは未完了リストへ移動しない',
      (WidgetTester tester) async {
    await pumpFlowDoApp(tester);
    await registerInboxTask(tester, 'スワイプテスト');

    final tile = inboxTaskTile('スワイプテスト');
    await tester.ensureVisible(tile);
    await settleFlowDoUi(tester);
    final topLeft = tester.getTopLeft(tile);
    await tester.dragFrom(
      Offset(topLeft.dx + 8, topLeft.dy + 24),
      const Offset(420, 0),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('リストへ移動中…'), findsNothing);
    expect(find.textContaining('追加したタスク', skipOffstage: false), findsOneWidget);

    await drainFlowDoTimers(tester);
  });
}
