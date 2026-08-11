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

  Future<void> promoteInboxTask(WidgetTester tester, String title) async {
    final categoryChip = find.descendant(
      of: find.ancestor(
        of: find.text(title, skipOffstage: false),
        matching: find.byType(Dismissible),
      ),
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
        matching: find.text('仕事'),
      ).last,
    );
    await tester.pump();
    await settleAfterDialogClosed(tester);
    await settleInboxPromoteDelay(tester);
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
    await promoteInboxTask(tester, '固定タスクA');
    await promoteInboxTask(tester, '固定タスクB');

    expect(find.text('固定タスクA', skipOffstage: false), findsOneWidget);
    expect(find.text('固定タスクB', skipOffstage: false), findsOneWidget);

    await tester.tap(pinButtonFor('固定タスクA'));
    await tester.pump();
    await settleFlowDoUi(tester);

    expect(find.text('固定タスクA', skipOffstage: false), findsOneWidget);
    expect(find.text('固定タスクB', skipOffstage: false), findsOneWidget);

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
