import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/models/category_item.dart';
import 'package:flowdo/models/task.dart';
import 'package:flowdo/theme/app_theme.dart';
import 'package:flowdo/widgets/task_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Phase1-5 情報密度改善', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 320));
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
          body: Container(
            color: Colors.white,
            child: Column(
              key: const ValueKey('task_tile_density_preview'),
              children: [
                TaskTile(
                  task: Task(
                    id: 1,
                    title: '買い物リストを作る',
                    isInbox: false,
                    categoryId: 'work',
                    dueDate: DateTime(2026, 8, 13),
                    reminderTime: const TimeOfDay(hour: 12, minute: 0),
                    isFavorite: true,
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
                  showDivider: true,
                ),
                TaskTile(
                  task: Task(
                    id: 2,
                    title: '提案書の下書き',
                    isInbox: false,
                    categoryId: 'work',
                    priorityStars: 3,
                    dueDate: DateTime(2026, 8, 17),
                    reminderTime: const TimeOfDay(hour: 9, minute: 5),
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
                  showDivider: true,
                ),
                TaskTile(
                  task: Task(
                    id: 3,
                    title: '週次レビュー',
                    isInbox: false,
                    categoryId: 'personal',
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byKey(const ValueKey('task_tile_density_preview')),
      matchesGoldenFile('goldens/task_tile_density_phase1_5.png'),
    );
  });
}
