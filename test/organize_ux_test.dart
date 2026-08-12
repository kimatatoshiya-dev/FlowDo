import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/widgets/flowdo_toast.dart';
import 'package:flowdo/widgets/organize_tasks_button.dart';

void main() {
  testWidgets('OrganizeTasksButton shows count label and folder icon',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrganizeTasksButton(
            count: 2,
            onPressed: () {},
          ),
        ),
      ),
    );

    expect(find.text('2件を整理する'), findsOneWidget);
    expect(find.text('🗂'), findsOneWidget);
    expect(find.byKey(const ValueKey('organize_tasks_button')), findsOneWidget);
  });

  testWidgets('FlowDoToast shows registration message briefly',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SizedBox.shrink()),
      ),
    );

    FlowDoToast.show(
      tester.element(find.byType(Scaffold)),
      '✅ 1件追加しました',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('✅ 1件追加しました'), findsOneWidget);

    await tester.pump(FlowDoToast.displayDuration);
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('✅ 1件追加しました'), findsNothing);
  });
}
