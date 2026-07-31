/// タスク編集シートの結果
sealed class TaskEditResult {
  const TaskEditResult();
}

/// 保存して閉じた
class TaskEditSaved extends TaskEditResult {
  const TaskEditSaved(this.title);

  final String title;
}

/// 削除して閉じた
class TaskEditDeleted extends TaskEditResult {
  const TaskEditDeleted();
}
