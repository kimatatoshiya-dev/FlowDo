import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flowdo/models/task.dart';
import 'package:flowdo/widgets/task_tile.dart';

import 'flowdo_test_helpers.dart';

Future<void> _pumpFlowDoWithTasks(WidgetTester tester, List<Task> tasks) async {
  await pumpFlowDoApp(
    tester,
    initialPreferences: {
      'flowdo_tasks': jsonEncode(tasks.map((task) => task.toJson()).toList()),
    },
  );
  Task.syncNextId(tasks);
}

Finder _taskTitle(String title) {
  return find.text(title, skipOffstage: false);
}

Finder _completedSectionTitle() {
  return find.descendant(
    of: find.byType(GroupedTaskList),
    matching: find.text('完了', skipOffstage: false),
  );
}

Finder _taskCheckbox(String title) {
  return find.descendant(
    of: find.ancestor(
      of: _taskTitle(title),
      matching: find.byType(Dismissible),
    ),
    matching: find.byType(AnimatedContainer),
  );
}

Future<void> _tapTaskCheckbox(WidgetTester tester, String title) async {
  await tester.ensureVisible(_taskTitle(title));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(_taskCheckbox(title));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(SharedPreferences.resetStatic);

  testWidgets('完了タップ後は未完了に留まり、2.5秒後に完了へ移る', (WidgetTester tester) async {
    await _pumpFlowDoWithTasks(
      tester,
      [Task(id: 0, title: 'テストタスク', isInbox: false)],
    );

    expect(_taskTitle('テストタスク'), findsOneWidget);
    expect(_completedSectionTitle(), findsNothing);

    await _tapTaskCheckbox(tester, 'テストタスク');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(_taskTitle('テストタスク'), findsOneWidget);
    expect(_completedSectionTitle(), findsNothing);

    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 300));

    expect(_completedSectionTitle(), findsOneWidget);
    expect(_taskTitle('テストタスク'), findsOneWidget);
  });

  testWidgets('完了待機中に再タップで取り消せる', (WidgetTester tester) async {
    await _pumpFlowDoWithTasks(
      tester,
      [Task(id: 0, title: '取り消しテスト', isInbox: false)],
    );

    await _tapTaskCheckbox(tester, '取り消しテスト');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await _tapTaskCheckbox(tester, '取り消しテスト');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 300));

    expect(_completedSectionTitle(), findsNothing);
    expect(_taskTitle('取り消しテスト'), findsOneWidget);
  });
}
