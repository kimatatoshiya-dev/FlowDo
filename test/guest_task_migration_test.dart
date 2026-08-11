import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/models/task.dart';
import 'package:flowdo/services/tasks/guest_task_migration.dart';

void main() {
  group('GuestTaskMigration.mergeTasks', () {
    test('ローカルタスクをリモートにマージする', () {
      final remote = [
        Task(id: 0, title: 'Remote only', isInbox: false, categoryId: 'work'),
      ];
      final local = [
        Task(id: 1, title: 'Guest task', isInbox: true),
      ];

      final merged = GuestTaskMigration.mergeTasks(
        localTasks: local,
        remoteTasks: remote,
      );

      expect(merged, hasLength(2));
      expect(merged.map((task) => task.title), containsAll(['Remote only', 'Guest task']));
    });

    test('同一 ID の衝突時はローカルを優先する', () {
      final remote = [
        Task(id: 0, title: 'Remote title', isInbox: false, categoryId: 'work'),
      ];
      final local = [
        Task(id: 0, title: 'Guest title', isInbox: true, categoryId: 'personal'),
      ];

      final merged = GuestTaskMigration.mergeTasks(
        localTasks: local,
        remoteTasks: remote,
      );

      expect(merged, hasLength(1));
      expect(merged.single.title, 'Guest title');
      expect(merged.single.categoryId, 'personal');
    });
  });
}
