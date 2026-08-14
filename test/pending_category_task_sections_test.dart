import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/models/category_item.dart';
import 'package:flowdo/models/pending_category_task_sections.dart';
import 'package:flowdo/models/task.dart';

void main() {
  final categories = [
    ...CategoryItem.defaults(),
    const CategoryItem(
      id: 'shopping',
      name: '買い物',
      colorValue: 0xFF34C759,
      displayOrder: 2,
    ),
    const CategoryItem(
      id: 'hobby',
      name: '趣味',
      colorValue: 0xFFAF52DE,
      displayOrder: 3,
    ),
  ];

  Task task({
    required int id,
    required String title,
    String categoryId = 'work',
    bool isFavorite = false,
    DateTime? dueDate,
    DateTime? createdAt,
  }) {
    return Task(
      id: id,
      title: title,
      categoryId: categoryId,
      isFavorite: isFavorite,
      dueDate: dueDate,
      isInbox: false,
      createdAt: createdAt ?? DateTime(2026, 1, id),
    );
  }

  group('comparePendingTasksInCategoryGroup', () {
    test('📌 → 🔥 → 🗓️7日 → 🗓️期限 → 期限なし → 作成順', () {
      final today = DateTime.now();
      final todayOnly = DateTime(today.year, today.month, today.day);
      final important = task(id: 1, title: 'important', isFavorite: true);
      final dueToday = task(
        id: 2,
        title: 'today',
        dueDate: todayOnly,
        createdAt: DateTime(2026, 1, 10),
      );
      final within7 = task(
        id: 3,
        title: 'within7',
        dueDate: todayOnly.add(const Duration(days: 3)),
      );
      final withDue = task(
        id: 4,
        title: 'later',
        dueDate: todayOnly.add(const Duration(days: 20)),
      );
      final noDue = task(id: 5, title: 'none');

      final sorted = [noDue, withDue, within7, dueToday, important]
        ..sort(comparePendingTasksInCategoryGroup);

      expect(sorted.map((entry) => entry.id).toList(), [1, 2, 3, 4, 5]);
    });
  });

  group('buildPendingCategoryTaskSections', () {
    test('複数グループ選択時は displayOrder 順にセクション分けする', () {
      final pending = [
        task(id: 1, title: 'h1', categoryId: 'hobby'),
        task(id: 2, title: 's1', categoryId: 'shopping'),
        task(id: 3, title: 's2', categoryId: 'shopping'),
        task(id: 4, title: 'h2', categoryId: 'hobby'),
      ];

      final sections = buildPendingCategoryTaskSections(
        pendingTasks: pending,
        selectedCategoryIds: {'shopping', 'hobby'},
        categories: categories,
      );

      expect(sections, isNotNull);
      expect(sections!.map((section) => section.category.id).toList(), [
        'shopping',
        'hobby',
      ]);
      expect(sections[0].tasks.map((entry) => entry.id).toList(), [3, 2]);
      expect(sections[1].tasks.map((entry) => entry.id).toList(), [4, 1]);
    });

    test('複数グループ選択時はグループ内を優先度順に並べる', () {
      final today = DateTime.now();
      final todayOnly = DateTime(today.year, today.month, today.day);
      final pending = [
        task(id: 1, title: 'plain', categoryId: 'shopping'),
        task(
          id: 2,
          title: 'important',
          categoryId: 'shopping',
          isFavorite: true,
        ),
        task(
          id: 3,
          title: 'today',
          categoryId: 'shopping',
          dueDate: todayOnly,
        ),
      ];

      final sections = buildPendingCategoryTaskSections(
        pendingTasks: pending,
        selectedCategoryIds: {'shopping', 'hobby'},
        categories: categories,
      );

      expect(
        sections!.single.tasks.map((entry) => entry.id).toList(),
        [2, 3, 1],
      );
    });

    test('単一グループ選択時も見出し付きセクションを返す', () {
      final pending = [
        task(id: 1, title: 'a', categoryId: 'shopping'),
        task(id: 2, title: 'b', categoryId: 'shopping'),
      ];

      final sections = buildPendingCategoryTaskSections(
        pendingTasks: pending,
        selectedCategoryIds: {'shopping'},
        categories: categories,
      );

      expect(sections, hasLength(1));
      expect(sections!.single.category.id, 'shopping');
      expect(sections.single.tasks.map((entry) => entry.id).toList(), [1, 2]);
    });

    test('フィルター未選択時は null', () {
      final sections = buildPendingCategoryTaskSections(
        pendingTasks: [task(id: 1, title: 'a')],
        selectedCategoryIds: {},
        categories: categories,
      );

      expect(sections, isNull);
    });
  });
}
