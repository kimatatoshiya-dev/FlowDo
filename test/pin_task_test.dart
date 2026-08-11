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

  Finder pinButtonFor(String title) {
    return find.descendant(
      of: find.ancestor(
        of: find.text(title, skipOffstage: false),
        matching: find.byType(Dismissible),
      ),
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
        of: find.ancestor(
          of: find.text('固定タスクB', skipOffstage: false),
          matching: find.byType(Dismissible),
        ),
        matching: find.byTooltip('固定を解除'),
      ),
    );
    await tester.pump();
    await settleFlowDoUi(tester);

    expect(find.text('固定タスクA', skipOffstage: false), findsOneWidget);
    expect(find.text('固定タスクB', skipOffstage: false), findsOneWidget);

    await drainFlowDoTimers(tester);
  });
}
