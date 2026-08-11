import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/models/today_focus.dart';
import 'package:flowdo/theme/app_theme.dart';
import 'package:flowdo/widgets/task_completion_toggle.dart';
import 'package:flowdo/widgets/today_focus_task_sheet.dart';

import 'home_dashboard_test.dart' show sampleTodayFocusSections;

void main() {
  testWidgets('完了トグルでコールバックが呼ばれる', (WidgetTester tester) async {
    final toggled = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TodayFocusTaskSheet(
            sections: sampleTodayFocusSections(),
            onToggleTask: (taskId) async {
              toggled.add(taskId);
            },
            isRemoving: (_) => false,
            showCompletedStyle: (_) => false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(TaskCompletionToggle).first);
    await tester.pump();

    expect(toggled, [1]);
  });

  testWidgets('完了スタイルと除去中アニメーションを反映する', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TodayFocusTaskSheet(
            sections: sampleTodayFocusSections(),
            onToggleTask: (_) async {},
            isRemoving: (taskId) => taskId == 1,
            showCompletedStyle: (taskId) => taskId == 2,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('重要タスク'), findsNothing);
    expect(find.text('今日タスク'), findsOneWidget);
    expect(find.byType(TaskCompletionToggle), findsNWidgets(2));
    expect(find.text('残り 1件'), findsOneWidget);
  });
}
