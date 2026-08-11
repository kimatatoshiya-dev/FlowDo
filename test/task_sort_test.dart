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
    test('手動順は固定タスクだけ最上位へ', () {
      final pinTime = DateTime(2026, 1, 1, 12);
      final tasks = [
        Task(id: 3, title: 'c', priorityStars: TaskPriorityStars.max),
        Task(id: 1, title: 'a', isFavorite: true, pinnedAt: pinTime),
        Task(id: 2, title: 'b', priorityStars: 1),
      ];

      final sorted = sortTaskList(tasks, TaskSortMode.manual, categories);

      expect(sorted.map((t) => t.id).toList(), [1, 2, 3]);
    });

    test('固定タスク同士は📌した順', () {
      final firstPin = DateTime(2026, 1, 1, 12);
      final secondPin = DateTime(2026, 1, 1, 13);
      final pinnedA = Task(
        id: 1,
        title: 'a',
        isFavorite: true,
        pinnedAt: firstPin,
      );
      final pinnedB = Task(
        id: 2,
        title: 'b',
        isFavorite: true,
        pinnedAt: secondPin,
      );

      expect(comparePinnedOrder(pinnedA, pinnedB), lessThan(0));

      final sorted = sortTaskList(
        [pinnedB, pinnedA],
        TaskSortMode.priority,
        categories,
      );
      expect(sorted.map((t) => t.id).toList(), [1, 2]);
    });

    test('固定タスクは優先度順でも最上位', () {
      final normalHigh = Task(id: 1, title: 'normal', priorityStars: 5);
      final importantLow = Task(
        id: 2,
        title: 'important',
        priorityStars: 1,
        isFavorite: true,
        pinnedAt: DateTime(2026, 1, 1),
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

  group('pinReorderIndex', () {
    test('固定 ON で既存固定の末尾へ', () {
      final pinTime = DateTime(2026, 1, 1, 12);
      final tasks = [
        Task(id: 1, title: 'a', isFavorite: true, pinnedAt: pinTime),
        Task(id: 2, title: 'b'),
      ];
      final pinned = Task(
        id: 3,
        title: 'c',
        isFavorite: true,
        pinnedAt: DateTime(2026, 1, 1, 13),
      );

      final index = pinReorderIndex(
        tasks: tasks,
        task: pinned,
        sortMode: TaskSortMode.priority,
        categories: categories,
      );

      expect(index, 1);
    });

    test('固定 ON で先頭固定がなければ先頭', () {
      final tasks = [
        Task(id: 1, title: 'a'),
        Task(id: 3, title: 'c'),
      ];
      final pinned = Task(
        id: 3,
        title: 'c',
        isFavorite: true,
        pinnedAt: DateTime(2026, 1, 1),
      );

      final index = pinReorderIndex(
        tasks: tasks,
        task: pinned,
        sortMode: TaskSortMode.priority,
        categories: categories,
      );

      expect(index, 0);
    });

    test('再📌は固定グループの末尾へ', () {
      final firstPin = DateTime(2026, 1, 1, 12);
      final secondPin = DateTime(2026, 1, 1, 13);
      final thirdPin = DateTime(2026, 1, 1, 14);
      final tasks = [
        Task(
          id: 1,
          title: 'a',
          isFavorite: true,
          pinnedAt: firstPin,
        ),
        Task(
          id: 2,
          title: 'b',
          isFavorite: true,
          pinnedAt: secondPin,
        ),
      ];
      final repinnedA = Task(
        id: 1,
        title: 'a',
        isFavorite: true,
        pinnedAt: thirdPin,
      );

      final index = pinReorderIndex(
        tasks: [tasks[1]],
        task: repinnedA,
        sortMode: TaskSortMode.priority,
        categories: categories,
      );

      expect(index, 1);
    });

    test('固定 OFF でもリストから消えない位置へ', () {
      final unpinned = Task(id: 1, title: 'pinned', priorityStars: 5);
      final remaining = [Task(id: 2, title: 'normal', priorityStars: 1)];

      final index = pinReorderIndex(
        tasks: remaining,
        task: unpinned,
        sortMode: TaskSortMode.priority,
        categories: categories,
      );

      expect(index, 1);
    });
  });

  group('splitPinnedTasks', () {
    test('固定タスクを先頭グループとして分割する', () {
      final a = Task(id: 1, title: 'a', isFavorite: true);
      final b = Task(id: 2, title: 'b');
      final c = Task(id: 3, title: 'c', isFavorite: true);

      final (pinned, unpinned) = splitPinnedTasks([a, b, c]);

      expect(pinned.map((t) => t.id), [1, 3]);
      expect(unpinned.map((t) => t.id), [2]);
    });
  });

  group('applyPinnedAtOrder', () {
    test('並び順どおりに pinnedAt を更新する', () {
      final a = Task(id: 1, title: 'a', isFavorite: true);
      final b = Task(id: 2, title: 'b', isFavorite: true);
      applyPinnedAtOrder([b, a]);

      expect(b.pinnedAt, isNotNull);
      expect(a.pinnedAt, isNotNull);
      expect(b.pinnedAt!.isBefore(a.pinnedAt!), isTrue);
    });
  });
}
