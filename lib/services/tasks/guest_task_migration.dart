import '../../models/task.dart';
import 'task_repository.dart';

/// ゲスト利用中のローカルタスクを、ログイン後のクラウドへ移行する。
abstract final class GuestTaskMigration {
  /// ローカルとリモートをマージし、両方へ書き込む。
  ///
  /// 同一 ID が衝突した場合はローカル（ゲスト）側を優先する。
  static Future<void> migrateLocalTasksToRemote({
    required TaskRepository local,
    required TaskRepository remote,
  }) async {
    final localTasks = await local.loadTasks();
    if (localTasks.isEmpty) return;

    final remoteTasks = await remote.loadTasks();
    final merged = mergeTasks(
      localTasks: localTasks,
      remoteTasks: remoteTasks,
    );

    await remote.syncTasks(merged);
    await local.syncTasks(merged);
  }

  static List<Task> mergeTasks({
    required List<Task> localTasks,
    required List<Task> remoteTasks,
  }) {
    final mergedById = {for (final task in remoteTasks) task.id: task};
    for (final localTask in localTasks) {
      mergedById[localTask.id] = localTask;
    }

    final merged = mergedById.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    Task.syncNextId(merged);
    return merged;
  }
}
