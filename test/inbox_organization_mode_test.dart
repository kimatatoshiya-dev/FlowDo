import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/models/category_item.dart';
import 'package:flowdo/models/task.dart';
import 'package:flowdo/widgets/inbox_organization_progress.dart';
import 'package:flowdo/widgets/task_tile.dart';
import 'package:flowdo/theme/app_theme.dart';

void main() {
  group('Task.isInboxUnorganized', () {
    test('true when category, due, time, and pin are unset', () {
      final task = Task.create(
        title: '未整理タスク',
        categoryId: CategoryItem.uncategorizedId,
      );
      expect(task.isInboxUnorganized, isTrue);
    });

    test('false when category is set', () {
      final task = Task.create(
        title: 'カテゴリー設定済み',
        categoryId: CategoryItem.defaultRegistrationCategoryId,
      );
      expect(task.isInboxUnorganized, isFalse);
    });

    test('false when due date is set', () {
      final task = Task.create(
        title: '期限あり',
        categoryId: CategoryItem.uncategorizedId,
      )..dueDate = DateTime(2026, 8, 20);
      expect(task.isInboxUnorganized, isFalse);
    });
  });

  testWidgets('InboxOrganizationProgress shows organized count', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: InboxOrganizationProgress(
            organizedCount: 4,
            totalCount: 8,
          ),
        ),
      ),
    );

    expect(find.text('整理中'), findsOneWidget);
    expect(find.text('4 / 8'), findsOneWidget);
  });

  testWidgets('Inbox unorganized task shows badge and hides after category set',
      (tester) async {
    final task = Task.create(
      title: '思考整理テスト',
      categoryId: CategoryItem.uncategorizedId,
    );
    final categories = CategoryItem.defaults();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TaskTile(
            task: task,
            category: categories.first,
            showCompletedStyle: false,
            isRemoving: false,
            isInboxList: true,
            onToggle: () {},
            onEdit: () {},
            onDelete: () {},
            onDismissDelete: () {},
            onCategoryTap: () {},
            onPriorityTap: () {},
            onDueDateTap: () {},
            onFavoriteTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('思考整理テスト'), findsOneWidget);

    task.categoryId = CategoryItem.defaultRegistrationCategoryId;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TaskTile(
            task: task,
            category: categories.firstWhere(
              (c) => c.id == CategoryItem.defaultRegistrationCategoryId,
            ),
            showCompletedStyle: false,
            isRemoving: false,
            isInboxList: true,
            onToggle: () {},
            onEdit: () {},
            onDelete: () {},
            onDismissDelete: () {},
            onCategoryTap: () {},
            onPriorityTap: () {},
            onDueDateTap: () {},
            onFavoriteTap: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.text('思考整理テスト'), findsOneWidget);
  });
}
