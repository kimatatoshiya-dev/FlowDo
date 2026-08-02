import '../../models/task.dart';

export 'fallback_task_repository.dart';
export 'firestore_task_repository.dart';
export 'local_task_repository.dart';

/// タスク永続化の抽象インターフェース
abstract class TaskRepository {
  /// リアルタイムでタスク一覧を監視する
  Stream<List<Task>> watchTasks();

  /// 全タスクを一度読み込む
  Future<List<Task>> loadTasks();

  Future<void> createTask(Task task);

  Future<void> updateTask(Task task);

  Future<void> deleteTask(int taskId);

  /// UI の一括更新パス向け: 現在のタスク一覧で永続化層を置き換える
  Future<void> syncTasks(List<Task> tasks);
}
