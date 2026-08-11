import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    return find.ancestor(
      of: find.text(title, skipOffstage: false),
      matching: find.byType(Dismissible),
    );
  }

  testWidgets('Inboxタスクのカテゴリタップでリストへ移動できる', (WidgetTester tester) async {
    await pumpFlowDoApp(tester);
    await registerInboxTask(tester, '移動テスト');

    expect(find.textContaining('追加したタスク', skipOffstage: false), findsOneWidget);
    expectManualOrganizeButtonVisible();

    final categoryChip = find.descendant(
      of: inboxTaskTile('移動テスト'),
      matching: find.text('仕事'),
    );
    await tester.ensureVisible(categoryChip);
    await settleFlowDoUi(tester);
    await tester.tap(categoryChip);
    await tester.pump();
    await settleFlowDoUi(tester);

    expect(find.text('どこに置きますか？'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('仕事'),
      ).last,
    );
    await tester.pump();
    await settleAfterDialogClosed(tester);

    expect(find.text('リストへ移動中…'), findsOneWidget);
    expect(find.textContaining('追加したタスク', skipOffstage: false), findsOneWidget);

    await settleInboxPromoteDelay(tester);

    expect(find.text('仕事へ移動しました'), findsOneWidget);
    expect(find.textContaining('追加したタスク', skipOffstage: false), findsNothing);

    final taskFinder = find.text('移動テスト', skipOffstage: false);
    await tester.ensureVisible(taskFinder);
    expect(taskFinder, findsOneWidget);

    await drainFlowDoTimers(tester);
  });

  testWidgets('Inboxタスクを右スワイプすると現在のカテゴリへ移動できる',
      (WidgetTester tester) async {
    await pumpFlowDoApp(tester);
    await registerInboxTask(tester, 'スワイプ移動');

    final tile = inboxTaskTile('スワイプ移動');
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

    expect(find.text('リストへ移動中…'), findsOneWidget);
    await settleInboxPromoteDelay(tester);

    expect(find.text('仕事へ移動しました'), findsOneWidget);
    expect(find.textContaining('追加したタスク', skipOffstage: false), findsNothing);
    final taskFinder = find.text('スワイプ移動', skipOffstage: false);
    await tester.ensureVisible(taskFinder);
    expect(taskFinder, findsOneWidget);

    await drainFlowDoTimers(tester);
  });
}
