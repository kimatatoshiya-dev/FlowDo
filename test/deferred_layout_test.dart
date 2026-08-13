import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flowdo/models/category_item.dart';
import 'package:flowdo/models/task.dart';
import 'package:flowdo/widgets/category_bar.dart';
import 'package:flowdo/widgets/task_swipe_actions.dart';
import 'package:flowdo/widgets/task_tile.dart';

import 'flowdo_test_helpers.dart';

Finder _taskTitle(String title) {
  return find.text(title, skipOffstage: false);
}

Finder _taskTile(String title) => taskTileForTitle(title);

Finder _categoryDotInTask(String taskTitle) {
  return find.descendant(
    of: _taskTile(taskTitle),
    matching: find.byKey(TaskTile.categoryColorDotKey),
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

    await pumpFlowDoApp(
      tester,
      initialPreferences: {
        'flowdo_tasks': jsonEncode([
          Task(
            id: 0,
            title: 'フィルターテスト',
            isInbox: false,
            categoryId: 'work',
          ).toJson(),
        ]),
        'flowdo_categories': jsonEncode(
          categories.map((category) => category.toJson()).toList(),
        ),
      },
    );
    Task.syncNextId([Task(id: 0, title: 'x', isInbox: false)]);

    expect(find.text('仕事'), findsWidgets);

    await revealPendingCategoryFilterBar(tester);
    final workFilter = find.descendant(
      of: find.byKey(const ValueKey('pending_category_filter_bar')),
      matching: find.text('仕事'),
    );
    await tester.tap(workFilter);
    await settleFlowDoUi(tester);

    await tester.ensureVisible(_taskTitle('フィルターテスト'));
    await settleFlowDoUi(tester);

    expect(_taskTitle('フィルターテスト'), findsOneWidget);

    await tester.tap(_categoryDotInTask('フィルターテスト'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(_taskTitle('フィルターテスト'), findsOneWidget);
    expect(_categoryDotInTask('フィルターテスト'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 300));
    await settleFlowDoUi(tester);

    expect(_taskTitle('フィルターテスト'), findsNothing);
  });

  testWidgets('優先度変更後も2.5秒間その場に留まる', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpFlowDoApp(
      tester,
      initialPreferences: {
        'flowdo_tasks': jsonEncode([
          Task(id: 0, title: '優先度テスト', isInbox: false, priorityStars: 0)
              .toJson(),
          Task(id: 1, title: '高優先度', isInbox: false, priorityStars: 5)
              .toJson(),
        ]),
      },
    );
    Task.syncNextId([
      Task(id: 0, title: 'a', isInbox: false),
      Task(id: 1, title: 'b', isInbox: false),
    ]);

    await tester.ensureVisible(_taskTitle('優先度テスト'));
    await settleFlowDoUi(tester);

    await tester.tap(_metaChipInTask('優先度テスト', '☆なし'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(_taskTitle('優先度テスト'), findsOneWidget);
    expect(_metaChipInTask('優先度テスト', '★5'), findsOneWidget);

    final beforeOrder = tester
        .widgetList<TaskSwipeActions>(find.byType(TaskSwipeActions))
        .map((swipe) => swipe.key)
        .toList();
    expect(beforeOrder.first, _taskTile('優先度テスト').evaluate().first.widget.key);

    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 300));
    await settleFlowDoUi(tester);

    expect(_taskTitle('優先度テスト'), findsOneWidget);
  });
}
