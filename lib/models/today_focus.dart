/// 今日やることの内訳（将来のフィルター連携用 ID）
enum TodayFocusFilterKind {
  important,
  dueToday,
  dueWithin7Days,
}

/// 詳細一覧に表示するタスク概要
class TodayFocusTaskItem {
  const TodayFocusTaskItem({
    required this.taskId,
    required this.title,
    this.categoryName,
  });

  final int taskId;
  final String title;
  final String? categoryName;
}

/// 今日やることの区分ごとのデータ
class TodayFocusSectionData {
  const TodayFocusSectionData({
    required this.kind,
    required this.label,
    required this.tasks,
  });

  final TodayFocusFilterKind kind;
  final String label;
  final List<TodayFocusTaskItem> tasks;

  int get count => tasks.length;
}

/// 詳細一覧1行分
class TodayFocusListEntry {
  const TodayFocusListEntry({
    required this.task,
    required this.kind,
  });

  final TodayFocusTaskItem task;
  final TodayFocusFilterKind kind;
}

/// 区分ごとのデータをフラット一覧へ変換する（重複は先勝ち）
List<TodayFocusListEntry> flattenTodayFocusSections(
  List<TodayFocusSectionData> sections,
) {
  final seenTaskIds = <int>{};
  final entries = <TodayFocusListEntry>[];

  for (final section in sections) {
    for (final task in section.tasks) {
      if (seenTaskIds.add(task.taskId)) {
        entries.add(
          TodayFocusListEntry(
            task: task,
            kind: section.kind,
          ),
        );
      }
    }
  }

  return entries;
}
