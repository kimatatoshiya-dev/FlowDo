import '../../models/task.dart';
import '../app_storage.dart';
import '../completed_task_cleanup.dart';

export 'fallback_task_repository.dart';
export 'firestore_task_repository.dart';
export 'local_task_repository.dart';

/// 保持期間設定に基づき、リポジトリの load/watch ストリーム向けにタスクを絞り込む
abstract final class TaskRepositoryRetention {
  static Future<List<Task>> filterRetained(List<Task> tasks) async {
    final retention = await AppStorage.loadCompletedTaskRetention();
    CompletedTaskCleanup.backfillCompletionTimestamps(tasks);
    return CompletedTaskCleanup.filterExpired(tasks, retention);
  }
}

/// タスク永続化の abstract interface
abstract class TaskRepository {
  /// リアルタイムでタスク一覧を監視する
  ///
  /// Firestore 実装は期限切れ完了タスクを除外して emit し、
  /// リモートからの削除は snapshot 処理中に行う（UI 側の syncTasks ループを避ける）。
  Stream<List<Task>> watchTasks();

  /// 全タスクを一度読み込む
  Future<List<Task>> loadTasks();

  Future<void> createTask(Task task);

  Future<void> updateTask(Task task);

  Future<void> deleteTask(int taskId);

  /// UI の一括更新パス向け: 現在のタスク一覧で永続化層を置き換える
  Future<void> syncTasks(List<Task> tasks);
}
