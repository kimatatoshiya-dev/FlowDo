import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/models/category_item.dart';
import 'package:flowdo/models/task.dart';
import 'package:flowdo/theme/app_theme.dart';
import 'package:flowdo/widgets/dashboard_category_task_sheet.dart';
import 'package:flowdo/widgets/task_completion_toggle.dart';

void main() {
  testWidgets('DashboardCategoryTaskSheet はカテゴリー内タスクを表示する',
      (WidgetTester tester) async {
    const category = CategoryItem(
      id: 'work',
      name: '仕事',
      colorValue: 0xFF007AFF,
    );
    final tasks = [
      Task(
        id: 1,
        title: '戦略会議資料',
        categoryId: 'work',
        isFavorite: true,
        dueDate: DateTime(2026, 8, 14),
      ),
      Task(
        id: 2,
        title: 'AB招待',
        categoryId: 'work',
      ),
    ];

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: DashboardCategoryTaskSheet(
            category: category,
            tasks: tasks,
            referenceToday: DateTime(2026, 8, 14),
            onTaskTap: (_) {},
            onToggleTask: (_) async {},
            isRemoving: (_) => false,
            showCompletedStyle: (_) => false,
          ),
        ),
      ),
    );

    expect(find.text('💼 仕事'), findsOneWidget);
    expect(find.text('戦略会議資料'), findsOneWidget);
    expect(find.text('AB招待'), findsOneWidget);
    expect(find.textContaining('🗓️'), findsOneWidget);
    expect(find.textContaining('📌'), findsOneWidget);
    expect(find.byType(TaskCompletionToggle), findsNWidgets(2));
  });

  testWidgets('DashboardCategoryTaskSheet タイトルタップで onTaskTap を呼ぶ',
      (WidgetTester tester) async {
    const category = CategoryItem(
      id: 'work',
      name: '仕事',
      colorValue: 0xFF007AFF,
    );
    final task = Task(
      id: 7,
      title: '資料作成',
      categoryId: 'work',
    );
    int? tappedId;

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: DashboardCategoryTaskSheet(
            category: category,
            tasks: [task],
            onTaskTap: (taskId) => tappedId = taskId,
            onToggleTask: (_) async {},
            isRemoving: (_) => false,
            showCompletedStyle: (_) => false,
          ),
        ),
      ),
    );

    await tester.tap(find.text('資料作成'));
    await tester.pump();

    expect(tappedId, 7);
  });
}
