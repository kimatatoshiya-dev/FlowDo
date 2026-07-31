import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/models/completed_task_retention.dart';
import 'package:flowdo/models/task.dart';
import 'package:flowdo/services/completed_task_cleanup.dart';

void main() {
  Task completedTask({
    required int id,
    required DateTime completedAt,
  }) {
    return Task(
      id: id,
      title: 'task$id',
      isCompleted: true,
      isInbox: false,
      completedAt: completedAt,
      createdAt: completedAt.subtract(const Duration(days: 1)),
    );
  }

  Task pendingTask({required int id}) {
    return Task(
      id: id,
      title: 'pending$id',
      isCompleted: false,
      isInbox: false,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  group('CompletedTaskCleanup', () {
    test('7日経過した完了タスクのみ削除する', () {
      final now = DateTime(2026, 7, 28, 12);
      final tasks = [
        pendingTask(id: 1),
        completedTask(id: 2, completedAt: now.subtract(const Duration(days: 6))),
        completedTask(id: 3, completedAt: now.subtract(const Duration(days: 7))),
        completedTask(id: 4, completedAt: now.subtract(const Duration(days: 8))),
      ];

      final filtered = CompletedTaskCleanup.filterExpired(
        tasks,
        CompletedTaskRetention.days7,
        now: now,
      );

      expect(filtered.map((t) => t.id).toList(), [1, 2]);
    });

    test('30日設定では7日経過タスクは残る', () {
      final now = DateTime(2026, 7, 28, 12);
      final tasks = [
        completedTask(id: 1, completedAt: now.subtract(const Duration(days: 10))),
        completedTask(id: 2, completedAt: now.subtract(const Duration(days: 30))),
      ];

      final filtered = CompletedTaskCleanup.filterExpired(
        tasks,
        CompletedTaskRetention.days30,
        now: now,
      );

      expect(filtered.map((t) => t.id).toList(), [1]);
    });

    test('自動削除しない設定では完了タスクを残す', () {
      final now = DateTime(2026, 7, 28, 12);
      final tasks = [
        completedTask(id: 1, completedAt: now.subtract(const Duration(days: 100))),
      ];

      final filtered = CompletedTaskCleanup.filterExpired(
        tasks,
        CompletedTaskRetention.never,
        now: now,
      );

      expect(filtered, hasLength(1));
    });

    test('完了日時未記録の完了タスクは createdAt で判定する', () {
      final now = DateTime(2026, 7, 28, 12);
      final task = Task(
        id: 1,
        title: 'legacy',
        isCompleted: true,
        isInbox: false,
        createdAt: now.subtract(const Duration(days: 8)),
      );

      CompletedTaskCleanup.backfillCompletionTimestamps([task]);

      expect(task.completedAt, task.createdAt);

      final filtered = CompletedTaskCleanup.filterExpired(
        [task],
        CompletedTaskRetention.days7,
        now: now,
      );

      expect(filtered, isEmpty);
    });
  });
}
