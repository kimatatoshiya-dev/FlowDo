import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/models/flowdo_dashboard_stats.dart';
import 'package:flowdo/models/task.dart';
import 'package:flowdo/models/task_repeat_type.dart';
import 'package:flowdo/widgets/dashboard/dashboard_memo_card.dart';

void main() {
  final today = DateTime(2026, 8, 11);

  test('dashboardTaskSummaryCounts は未完了タスクを集計する', () {
    final counts = dashboardTaskSummaryCounts(
      [
        Task(id: 1, title: '重要', isInbox: false, isFavorite: true),
        Task(
          id: 2,
          title: '今日',
          isInbox: false,
          dueDate: today,
        ),
        Task(
          id: 3,
          title: '7日以内',
          isInbox: false,
          dueDate: today.add(const Duration(days: 5)),
        ),
        Task(
          id: 4,
          title: '完了',
          isInbox: false,
          isCompleted: true,
          dueDate: today,
        ),
      ],
      referenceToday: today,
    );

    expect(counts.importantCount, 1);
    expect(counts.dueTodayCount, 1);
    expect(counts.dueWithin7DaysCount, 2);
  });

  test('dashboardRoutineStats は完了数と全体数を返す', () {
    final stats = dashboardRoutineStats(
      [
        Task(
          id: 1,
          title: '朝',
          isInbox: false,
          repeatType: TaskRepeatType.daily,
          isCompleted: true,
          completedAt: today,
        ),
        Task(
          id: 2,
          title: '夜',
          isInbox: false,
          repeatType: TaskRepeatType.weekly,
        ),
      ],
      referenceToday: today,
    );

    expect(stats.completedCount, 1);
    expect(stats.totalCount, 2);
    expect(stats.displayValue, '1 / 2');
  });

  test('DashboardMemoCard.previewText は先頭3行まで表示する', () {
    expect(
      DashboardMemoCard.previewText(''),
      '今日の気付き・反省・アイデアを書きましょう',
    );
    expect(
      DashboardMemoCard.previewText('郵便局\n\nコピー\nメモ\n4行目'),
      '郵便局\nコピー\nメモ',
    );
  });
}
