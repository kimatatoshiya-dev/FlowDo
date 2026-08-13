import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flowdo/widgets/task_swipe_actions.dart';

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

  Finder pinButtonFor(String title) {
    return find.descendant(
      of: taskTileForTitle(title),
      matching: find.byTooltip('最上位へ固定'),
    );
  }

  testWidgets('📌切替で他タスクが消えない', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpFlowDoApp(
      tester,
      initialPreferences: {
        'flowdo_input_guidance_seen': true,
        'flowdo_inbox_guidance_seen': true,
        'flowdo_favorite_guidance_seen': true,
      },
    );

    await registerInboxTask(tester, '固定タスクA');
    await registerInboxTask(tester, '固定タスクB');
    await organizeInboxTasks(tester, count: 2);

    expect(find.text('固定タスクA', skipOffstage: false), findsOneWidget);
    expect(find.text('固定タスクB', skipOffstage: false), findsOneWidget);

    await tester.ensureVisible(pinButtonFor('固定タスクA'));
    await settleFlowDoUi(tester);
    await tester.tap(pinButtonFor('固定タスクA'));
    await tester.pump();
    await settleFlowDoUi(tester);

    expect(find.text('固定タスクA', skipOffstage: false), findsOneWidget);
    expect(find.text('固定タスクB', skipOffstage: false), findsOneWidget);

    await tester.ensureVisible(pinButtonFor('固定タスクB'));
    await settleFlowDoUi(tester);
    await tester.tap(pinButtonFor('固定タスクB'));
    await tester.pump();
    await settleFlowDoUi(tester);

    expect(find.text('固定タスクA', skipOffstage: false), findsOneWidget);
    expect(find.text('固定タスクB', skipOffstage: false), findsOneWidget);
    expect(find.text('最重要に固定しました'), findsWidgets);

    await tester.tap(
      find.descendant(
        of: taskTileForTitle('固定タスクB'),
        matching: find.byTooltip('固定を解除'),
      ),
    );
    await tester.pump();
    await settleFlowDoUi(tester);

    expect(find.text('固定タスクA', skipOffstage: false), findsOneWidget);
    expect(find.text('固定タスクB', skipOffstage: false), findsOneWidget);

    await drainFlowDoTimers(tester);
  });

  testWidgets('📌固定後は約0.7秒その場に留まり、のち固定セクションへ移動する', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpFlowDoApp(
      tester,
      initialPreferences: {
        'flowdo_input_guidance_seen': true,
        'flowdo_inbox_guidance_seen': true,
        'flowdo_favorite_guidance_seen': true,
      },
    );

    await registerInboxTask(tester, '下で固定する');
    await registerInboxTask(tester, '上のタスク');
    await organizeInboxTasks(tester, count: 2);

    await tester.ensureVisible(pinButtonFor('下で固定する'));
    await settleFlowDoUi(tester);

    final topBeforePin = tester
        .widgetList<TaskSwipeActions>(find.byType(TaskSwipeActions))
        .map((swipe) => swipe.key)
        .first;
    expect(topBeforePin, taskTileForTitle('上のタスク').evaluate().first.widget.key);

    await tester.tap(pinButtonFor('下で固定する'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.descendant(
        of: taskTileForTitle('下で固定する'),
        matching: find.byTooltip('固定を解除'),
      ),
      findsOneWidget,
    );

    final topDuringHold = tester
        .widgetList<TaskSwipeActions>(find.byType(TaskSwipeActions))
        .map((swipe) => swipe.key)
        .first;
    expect(topDuringHold, taskTileForTitle('上のタスク').evaluate().first.widget.key);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 250));
    await settleFlowDoUi(tester);

    final topAfterMove = tester
        .widgetList<TaskSwipeActions>(find.byType(TaskSwipeActions))
        .map((swipe) => swipe.key)
        .first;
    expect(
      topAfterMove,
      taskTileForTitle('下で固定する').evaluate().first.widget.key,
    );

    await drainFlowDoTimers(tester);
  });
}
