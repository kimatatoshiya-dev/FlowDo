import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'flowdo_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(SharedPreferences.resetStatic);

  testWidgets('最近追加タスクをタップすると編集シートが開く', (WidgetTester tester) async {
    await pumpFlowDoApp(tester);

    await tester.enterText(
      find.byKey(const ValueKey('task_input_field')),
      '編集対象',
    );
    await tester.tap(find.text('登録'));
    await tester.pump();
    await settleAfterTaskRegistration(tester);

    await openTaskEditBySwipe(tester, '編集対象');

    expect(find.text('タスクを編集'), findsOneWidget);
    expect(find.text('キャンセル'), findsOneWidget);
    expect(find.text('削除'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);

    await drainFlowDoTimers(tester);
  });

  testWidgets('編集シートで名前を保存できる', (WidgetTester tester) async {
    await pumpFlowDoApp(tester);

    await tester.enterText(
      find.byKey(const ValueKey('task_input_field')),
      '旧タイトル',
    );
    await tester.tap(find.text('登録'));
    await tester.pump();
    await settleAfterTaskRegistration(tester);

    await openTaskEditBySwipe(tester, '旧タイトル');

    expect(find.text('タスクを編集'), findsOneWidget);

    final editField = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(editField);
    await tester.tap(editField);
    await tester.enterText(editField, '新タイトル');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settleAfterDialogClosed(tester);
    await settleFlowDoUi(tester);

    expect(find.text('新タイトル', skipOffstage: false), findsOneWidget);
    expect(find.text('旧タイトル', skipOffstage: false), findsNothing);

    await drainFlowDoTimers(tester);
  });
}
