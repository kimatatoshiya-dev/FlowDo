import 'package:flutter_test/flutter_test.dart';
import 'package:flowdo/models/category_item.dart';
import 'package:flowdo/models/task.dart';
import 'package:flowdo/models/task_priority.dart';
import 'package:flowdo/models/task_sort_mode.dart';

void main() {
  final categories = [
    ...CategoryItem.defaults(),
    CategoryItem.create(name: '仕事', colorValue: 0xFF007AFF),
    CategoryItem.create(name: '私用', colorValue: 0xFF34C759),
  ];

  group('compareTasksBySortMode', () {
    test('優先度順は星の多い順', () {
      final low = Task(id: 1, title: 'a', priorityStars: 1);
      final high = Task(id: 2, title: 'b', priorityStars: 5);
      final none = Task(id: 3, title: 'c', priorityStars: 0);

      expect(
        compareTasksBySortMode(high, low, TaskSortMode.priority, categories),
        lessThan(0),
      );
      expect(
        compareTasksBySortMode(high, none, TaskSortMode.priority, categories),
        lessThan(0),
      );
      expect(
        compareTasksBySortMode(low, none, TaskSortMode.priority, categories),
        lessThan(0),
      );
    });

    test('期限切れと今日期限は優先度より上位', () {
      final high = Task(id: 1, title: 'high', priorityStars: 5);
      final overdue = Task(
        id: 2,
        title: 'overdue',
        priorityStars: 1,
        dueDate: DateTime(2020, 1, 1),
      );
      final dueToday = Task(
        id: 3,
        title: 'today',
        priorityStars: 2,
        dueDate: DateTime.now(),
      );

      expect(
        compareTasksBySortMode(overdue, high, TaskSortMode.priority, categories),
        lessThan(0),
      );
      expect(
        compareTasksBySortMode(dueToday, high, TaskSortMode.priority, categories),
        lessThan(0),
      );
      expect(
        compareTasksBySortMode(overdue, dueToday, TaskSortMode.priority, categories),
        lessThan(0),
      );
    });

    test('同じ優先度は作成日時の新しい順', () {
      final older = Task(
        id: 1,
        title: 'older',
        priorityStars: 5,
        createdAt: DateTime(2026, 1, 1),
      );
      final newer = Task(
        id: 2,
        title: 'newer',
        priorityStars: 5,
        createdAt: DateTime(2026, 1, 10),
      );

      expect(
        compareTasksBySortMode(newer, older, TaskSortMode.priority, categories),
        lessThan(0),
      );
    });

    test('期限順は近い期限が先、期限なしは後', () {
      final withDue = Task(
        id: 1,
        title: 'a',
        dueDate: DateTime(2026, 1, 10),
      );
      final withoutDue = Task(id: 2, title: 'b');
      final laterDue = Task(
        id: 3,
        title: 'c',
        dueDate: DateTime(2026, 2, 1),
      );

      expect(
        compareTasksBySortMode(withDue, laterDue, TaskSortMode.dueDate, categories),
        lessThan(0),
      );
      expect(
        compareTasksBySortMode(withDue, withoutDue, TaskSortMode.dueDate, categories),
        lessThan(0),
      );
    });

    test('カテゴリー順はカテゴリー一覧の順', () {
      final uncategorized = Task(id: 1, title: 'a');
      final work = Task(id: 2, title: 'b', categoryId: categories[1].id);

      expect(
        compareTasksBySortMode(
          uncategorized,
          work,
          TaskSortMode.category,
          categories,
        ),
        lessThan(0),
      );
    });
  });

  group('sortTaskList', () {
    test('手動順は重要タスクだけ最上位へ', () {
      final tasks = [
        Task(id: 3, title: 'c', priorityStars: TaskPriorityStars.max),
        Task(id: 1, title: 'a', isFavorite: true),
        Task(id: 2, title: 'b', priorityStars: 1),
      ];

      final sorted = sortTaskList(tasks, TaskSortMode.manual, categories);

      expect(sorted.map((t) => t.id).toList(), [1, 2, 3]);
    });

    test('重要タスクは優先度順でも最上位', () {
      final normalHigh = Task(id: 1, title: 'normal', priorityStars: 5);
      final importantLow = Task(
        id: 2,
        title: 'important',
        priorityStars: 1,
        isFavorite: true,
      );

      expect(
        compareTasksBySortMode(
          importantLow,
          normalHigh,
          TaskSortMode.priority,
          categories,
        ),
        lessThan(0),
      );
    });

    test('優先度順で未完了・完了をそれぞれ並び替える', () {
      final tasks = [
        Task(id: 1, title: 'pending low', priorityStars: 1),
        Task(id: 2, title: 'pending high', priorityStars: 5),
        Task(
          id: 3,
          title: 'done old',
          isCompleted: true,
          priorityStars: 5,
          completedAt: DateTime(2026, 1, 1),
        ),
        Task(
          id: 4,
          title: 'done new',
          isCompleted: true,
          priorityStars: 1,
          completedAt: DateTime(2026, 1, 10),
        ),
      ];

      final sorted = sortTaskList(tasks, TaskSortMode.priority, categories);

      expect(sorted.map((t) => t.id).toList(), [2, 1, 4, 3]);
    });

    test('完了タスクは完了日時の降順', () {
      final older = Task(
        id: 1,
        title: 'older',
        isCompleted: true,
        completedAt: DateTime(2026, 1, 1),
      );
      final newer = Task(
        id: 2,
        title: 'newer',
        isCompleted: true,
        completedAt: DateTime(2026, 1, 15),
      );

      expect(compareCompletedTasks(newer, older), lessThan(0));

      final completed = [older, newer]..sort(compareCompletedTasks);
      expect(completed.map((t) => t.id).toList(), [2, 1]);
    });
  });
}
