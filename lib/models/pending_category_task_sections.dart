import 'category_item.dart';
import 'task.dart';

/// 未完了リストのカテゴリーセクション
class PendingCategoryTaskSection {
  const PendingCategoryTaskSection({
    required this.category,
    required this.tasks,
  });

  final CategoryItem category;
  final List<Task> tasks;
}

/// グループ内表示順: 📌 → 🔥 → 🗓️7日 → 🗓️期限 → 期限なし → 作成順
int pendingCategoryGroupDisplayRank(Task task) {
  if (task.isFavorite) return 0;
  if (task.isDueToday) return 1;
  if (task.isDueWithin7Days) return 2;
  if (task.dueDate != null) return 3;
  return 4;
}

int comparePendingTasksInCategoryGroup(Task a, Task b) {
  final rankCompare = pendingCategoryGroupDisplayRank(a)
      .compareTo(pendingCategoryGroupDisplayRank(b));
  if (rankCompare != 0) return rankCompare;

  final createdCompare = b.createdAt.compareTo(a.createdAt);
  if (createdCompare != 0) return createdCompare;
  return b.id.compareTo(a.id);
}

/// カテゴリーフィルター選択時のセクション一覧を組み立てる
List<PendingCategoryTaskSection>? buildPendingCategoryTaskSections({
  required List<Task> pendingTasks,
  required Set<String> selectedCategoryIds,
  required List<CategoryItem> categories,
}) {
  if (selectedCategoryIds.isEmpty || pendingTasks.isEmpty) {
    return null;
  }

  final orderedCategories = CategoryItem.filterBarCategories(categories)
      .where((category) => selectedCategoryIds.contains(category.id))
      .toList(growable: false);
  if (orderedCategories.isEmpty) return null;

  final useGroupSort = selectedCategoryIds.length >= 2;
  final sections = <PendingCategoryTaskSection>[];

  for (final category in orderedCategories) {
    final tasks = pendingTasks
        .where((task) => task.categoryId == category.id)
        .toList(growable: false);
    if (tasks.isEmpty) continue;

    if (useGroupSort) {
      tasks.sort(comparePendingTasksInCategoryGroup);
    }

    sections.add(
      PendingCategoryTaskSection(category: category, tasks: tasks),
    );
  }

  return sections.isEmpty ? null : sections;
}
