import 'category_item.dart';
import 'task.dart';

/// タスク一覧の並び替え方法
enum TaskSortMode {
  manual('手動順'),
  priority('優先度順'),
  dueDate('期限順'),
  category('カテゴリー順');

  const TaskSortMode(this.label);

  final String label;
}

/// 固定（📌）タスクを同一グループ内の最上位に並べる
int compareFavoriteFirst(Task a, Task b) {
  if (a.isFavorite == b.isFavorite) return 0;
  return a.isFavorite ? -1 : 1;
}

/// 固定 ON/OFF 後に [_tasks] 全体へ挿入するインデックス
int pinReorderIndex({
  required List<Task> tasks,
  required Task task,
  required TaskSortMode sortMode,
  required List<CategoryItem> categories,
}) {
  if (task.isInbox) {
    if (task.isFavorite) {
      for (var i = 0; i < tasks.length; i++) {
        final t = tasks[i];
        if (t.isInbox && !t.isCompleted) return i;
      }
      return tasks.length;
    }

    for (var i = 0; i < tasks.length; i++) {
      final t = tasks[i];
      if (!t.isInbox || t.isCompleted) continue;
      if (t.isFavorite) continue;
      if (task.createdAt.isAfter(t.createdAt)) return i;
    }
    for (var i = tasks.length - 1; i >= 0; i--) {
      if (tasks[i].isInbox && !tasks[i].isCompleted) return i + 1;
    }
    return tasks.length;
  }

  if (task.isFavorite) {
    for (var i = 0; i < tasks.length; i++) {
      final t = tasks[i];
      if (!t.isCompleted && !t.isInbox) return i;
    }
    return tasks.length;
  }

  for (var i = 0; i < tasks.length; i++) {
    final t = tasks[i];
    if (t.isCompleted || t.isInbox) continue;
    if (t.isFavorite) continue;
    if (compareTasksBySortMode(task, t, sortMode, categories) < 0) {
      return i;
    }
  }

  for (var i = tasks.length - 1; i >= 0; i--) {
    if (!tasks[i].isCompleted && !tasks[i].isInbox) {
      return i + 1;
    }
  }
  return tasks.length;
}

/// 並び替えモードに応じてタスクを比較する（固定タスクは常に上位）
int compareTasksBySortMode(
  Task a,
  Task b,
  TaskSortMode mode,
  List<CategoryItem> categories,
) {
  final favoriteCompare = compareFavoriteFirst(a, b);
  if (favoriteCompare != 0) return favoriteCompare;

  return switch (mode) {
    TaskSortMode.manual => a.id.compareTo(b.id),
    TaskSortMode.priority => _compareByPriority(a, b),
    TaskSortMode.dueDate => _compareByDueDate(a, b),
    TaskSortMode.category => _compareByCategory(a, b, categories),
  };
}

int _compareByPriority(Task a, Task b) {
  final urgencyCompare = _urgencyRank(a).compareTo(_urgencyRank(b));
  if (urgencyCompare != 0) return urgencyCompare;

  final priorityCompare = b.priorityStars.compareTo(a.priorityStars);
  if (priorityCompare != 0) return priorityCompare;

  return _compareByCreatedAtDesc(a, b);
}

/// 期限切れ → 今日期限 → 通常 の順（優先度より上位）
int _urgencyRank(Task task) {
  if (task.isOverdue) return 0;
  if (task.isDueToday) return 1;
  return 2;
}

int _compareByCreatedAtDesc(Task a, Task b) {
  final createdCompare = b.createdAt.compareTo(a.createdAt);
  if (createdCompare != 0) return createdCompare;
  return b.id.compareTo(a.id);
}

int _compareByDueDate(Task a, Task b) {
  if (a.dueDate != null && b.dueDate != null) {
    final dueCompare = a.dueDate!.compareTo(b.dueDate!);
    if (dueCompare != 0) return dueCompare;
    return _compareByCreatedAtDesc(a, b);
  }
  if (a.dueDate != null) return -1;
  if (b.dueDate != null) return 1;

  return _compareByCreatedAtDesc(a, b);
}

int _compareByCategory(Task a, Task b, List<CategoryItem> categories) {
  final categoryCompare = _categoryIndex(a.categoryId, categories)
      .compareTo(_categoryIndex(b.categoryId, categories));
  if (categoryCompare != 0) return categoryCompare;

  return _compareByPriority(a, b);
}

int _categoryIndex(String categoryId, List<CategoryItem> categories) {
  final index = categories.indexWhere((c) => c.id == categoryId);
  return index < 0 ? categories.length : index;
}

/// 完了タスクを「完了した日時」の降順で比較する
int compareCompletedTasks(Task a, Task b) {
  final aKey = a.completedAt ?? a.createdAt;
  final bKey = b.completedAt ?? b.createdAt;
  final timeCompare = bKey.compareTo(aKey);
  if (timeCompare != 0) return timeCompare;
  return b.id.compareTo(a.id);
}

/// 未完了・完了それぞれのグループ内で並び替えを適用する
List<Task> sortTaskList(
  List<Task> tasks,
  TaskSortMode mode,
  List<CategoryItem> categories,
) {
  final pending = tasks.where((t) => !t.isCompleted).toList()
    ..sort((a, b) => compareTasksBySortMode(a, b, mode, categories));
  final completed = tasks.where((t) => t.isCompleted).toList()
    ..sort(compareCompletedTasks);

  return [...pending, ...completed];
}
