import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flowdo/main.dart';
import 'package:flowdo/services/analytics/noop_analytics_service.dart';
import 'package:flowdo/services/auth/noop_auth_service.dart';
import 'package:flowdo/services/tasks/local_task_repository.dart';
import 'package:flowdo/models/category_item.dart';
import 'package:flowdo/models/task.dart';
import 'package:flowdo/widgets/category_bar.dart';

Future<void> _pumpFlowDo(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      break;
    }
  }
  await tester.pumpAndSettle();
}

Finder _taskTitle(String title) {
  return find.text(title, skipOffstage: false);
}

Finder _taskTile(String title) {
  return find.ancestor(
    of: _taskTitle(title),
    matching: find.byType(Dismissible),
  );
}

Finder _metaChipInTask(String taskTitle, String label) {
  return find.descendant(
    of: _taskTile(taskTitle),
    matching: find.text(label, skipOffstage: false),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(SharedPreferences.resetStatic);

  testWidgets('カテゴリー変更後は2.5秒間その場に留まり、のちフィルターから外れる', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const categories = [
      CategoryItem(
        id: CategoryItem.uncategorizedId,
        name: '未分類',
        colorValue: 0xFF8E8E93,
        isSystem: true,
      ),
      CategoryItem(id: 'work', name: '仕事', colorValue: 0xFF007AFF),
    ];

    SharedPreferences.setMockInitialValues({
      'flowdo_tasks': jsonEncode([
        Task(
          id: 0,
          title: 'フィルターテスト',
          isInbox: false,
          categoryId: 'work',
        ).toJson(),
      ]),
      'flowdo_categories': jsonEncode(categories.map((c) => c.toJson()).toList()),
    });
    Task.syncNextId([Task(id: 0, title: 'x', isInbox: false)]);

    await tester.pumpWidget(FlowDoApp(analyticsService: NoOpAnalyticsService(), authService: NoOpAuthService(), taskRepository: LocalTaskRepository()));
    await _pumpFlowDo(tester);

    expect(find.text('仕事'), findsWidgets);

    final workFilter = find.descendant(
      of: find.byType(CategoryBar),
      matching: find.text('仕事'),
    );
    await tester.ensureVisible(workFilter);
    await tester.tap(workFilter);
    await tester.pumpAndSettle();

    await tester.ensureVisible(_taskTitle('フィルターテスト'));
    await tester.pumpAndSettle();

    expect(_taskTitle('フィルターテスト'), findsOneWidget);

    await tester.tap(_metaChipInTask('フィルターテスト', '仕事'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(_taskTitle('フィルターテスト'), findsOneWidget);
    expect(_metaChipInTask('フィルターテスト', '未分類'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(_taskTitle('フィルターテスト'), findsNothing);
  });

  testWidgets('優先度変更後も2.5秒間その場に留まる', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({
      'flowdo_tasks': jsonEncode([
        Task(id: 0, title: '優先度テスト', isInbox: false, priorityStars: 0).toJson(),
        Task(id: 1, title: '高優先度', isInbox: false, priorityStars: 5).toJson(),
      ]),
    });
    Task.syncNextId([
      Task(id: 0, title: 'a', isInbox: false),
      Task(id: 1, title: 'b', isInbox: false),
    ]);

    await tester.pumpWidget(FlowDoApp(analyticsService: NoOpAnalyticsService(), authService: NoOpAuthService(), taskRepository: LocalTaskRepository()));
    await _pumpFlowDo(tester);

    await tester.ensureVisible(_taskTitle('優先度テスト'));
    await tester.pumpAndSettle();

    await tester.tap(_metaChipInTask('優先度テスト', '☆なし'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(_taskTitle('優先度テスト'), findsOneWidget);
    expect(_metaChipInTask('優先度テスト', '★5'), findsOneWidget);

    // 2.5秒待機中は並び順を維持（上の方に留まる）
    final beforeOrder = tester
        .widgetList<Dismissible>(find.byType(Dismissible))
        .map((d) => d.key)
        .toList();
    expect(beforeOrder.first, _taskTile('優先度テスト').evaluate().first.widget.key);

    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(_taskTitle('優先度テスト'), findsOneWidget);
  });
}
