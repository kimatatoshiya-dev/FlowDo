import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/models/category_item.dart';
import 'package:flowdo/models/task.dart';
import 'package:flowdo/theme/app_theme.dart';
import 'package:flowdo/widgets/task_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Phase1-3 カテゴリカラー丸表示', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 240));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const categories = [
      CategoryItem(
        id: CategoryItem.uncategorizedId,
        name: '未分類',
        colorValue: 0xFF8E8E93,
        isSystem: true,
      ),
      CategoryItem(id: 'work', name: '仕事', colorValue: 0xFF007AFF),
      CategoryItem(id: 'personal', name: '家庭', colorValue: 0xFF34C759),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          backgroundColor: const Color(0xFFF2F2F7),
          body: Column(
            key: const ValueKey('task_category_dot_preview'),
            children: [
              TaskTile(
                task: Task(
                  id: 1,
                  title: '仕事のタスク',
                  isInbox: false,
                  categoryId: 'work',
                  dueDate: DateTime(2026, 8, 13),
                ),
                category: categories[1],
                showCompletedStyle: false,
                isRemoving: false,
                onToggle: () {},
                onEdit: () {},
                onDelete: () {},
                onDismissDelete: () {},
                onCategoryTap: () {},
                onPriorityTap: () {},
                onDueDateTap: () {},
                onFavoriteTap: () {},
                showDivider: false,
                isInboxList: false,
              ),
              TaskTile(
                task: Task(
                  id: 2,
                  title: '家庭の買い物',
                  isInbox: false,
                  categoryId: 'personal',
                  priorityStars: 3,
                ),
                category: categories[2],
                showCompletedStyle: false,
                isRemoving: false,
                onToggle: () {},
                onEdit: () {},
                onDelete: () {},
                onDismissDelete: () {},
                onCategoryTap: () {},
                onPriorityTap: () {},
                onDueDateTap: () {},
                onFavoriteTap: () {},
                showDivider: false,
                isInboxList: false,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byKey(const ValueKey('task_category_dot_preview')),
      matchesGoldenFile('goldens/task_category_dot.png'),
    );
  });
}
