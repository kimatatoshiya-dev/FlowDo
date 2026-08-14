import 'package:flutter/material.dart';

import '../models/category_item.dart';
import '../models/flowdo_calendar.dart';
import '../models/task.dart';
import '../utils/date_formatter.dart';
import '../theme/app_theme.dart';
import 'home_dashboard.dart' show categoryEmoji;
import 'task_completion_toggle.dart';

/// ダッシュボード カテゴリー行タップ時の未完了タスク一覧 BottomSheet
class DashboardCategoryTaskSheet extends StatelessWidget {
  const DashboardCategoryTaskSheet({
    super.key,
    required this.category,
    required this.tasks,
    required this.onTaskTap,
    required this.onToggleTask,
    required this.isRemoving,
    required this.showCompletedStyle,
    this.referenceToday,
  });

  static const sheetHeightFactor = 0.75;
  static const rowHeight = 56.0;

  final CategoryItem category;
  final List<Task> tasks;
  final ValueChanged<int> onTaskTap;
  final Future<void> Function(int taskId) onToggleTask;
  final bool Function(int taskId) isRemoving;
  final bool Function(int taskId) showCompletedStyle;
  final DateTime? referenceToday;

  static Future<void> show(
    BuildContext context, {
    required CategoryItem category,
    required List<Task> tasks,
    required ValueChanged<int> onTaskTap,
    required Future<void> Function(int taskId) onToggleTask,
    required bool Function(int taskId) isRemoving,
    required bool Function(int taskId) showCompletedStyle,
    DateTime? referenceToday,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DashboardCategoryTaskSheet(
        category: category,
        tasks: tasks,
        onTaskTap: onTaskTap,
        onToggleTask: onToggleTask,
        isRemoving: isRemoving,
        showCompletedStyle: showCompletedStyle,
        referenceToday: referenceToday,
      ),
    );
  }

  String get _title => '${categoryEmoji(category)} ${category.name}';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final sheetHeight = screenHeight * sheetHeightFactor;
    final today = dateOnly(referenceToday ?? DateTime.now());

    return SafeArea(
      child: SizedBox(
        height: sheetHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: tasks.isEmpty
                    ? Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          '未完了タスクはありません',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colors.secondaryLabel,
                                  ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: tasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          final removing = isRemoving(task.id);

                          return AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                            alignment: Alignment.topCenter,
                            child: removing
                                ? const SizedBox.shrink()
                                : _DashboardCategoryTaskRow(
                                    task: task,
                                    referenceToday: today,
                                    completed: showCompletedStyle(task.id),
                                    onToggle: () => onToggleTask(task.id),
                                    onTitleTap: () => onTaskTap(task.id),
                                  ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardCategoryTaskRow extends StatelessWidget {
  const _DashboardCategoryTaskRow({
    required this.task,
    required this.referenceToday,
    required this.completed,
    required this.onToggle,
    required this.onTitleTap,
  });

  final Task task;
  final DateTime referenceToday;
  final bool completed;
  final VoidCallback onToggle;
  final VoidCallback onTitleTap;

  String? get _metaLabel {
    final parts = <String>[];
    final dueDate = task.dueDate;
    if (dueDate != null) {
      parts.add(
        '🗓️ ${DateFormatter.formatDueDateWithWeekday(dueDate, reference: referenceToday)}',
      );
      final reminderTime = task.reminderTime;
      if (reminderTime != null) {
        parts.add(DateFormatter.formatReminderTimeChip(reminderTime));
      }
    }
    if (task.isFavorite) {
      parts.add('📌');
    }
    if (parts.isEmpty) return null;
    return parts.join('　');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;
    final metaLabel = _metaLabel;

    return Material(
      color: colors.groupedSurface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: metaLabel == null
            ? DashboardCategoryTaskSheet.rowHeight
            : DashboardCategoryTaskSheet.rowHeight + 18,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              TaskCompletionToggle(
                completed: completed,
                onTap: onToggle,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTitleTap,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      decoration: completed
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: completed
                                          ? colors.secondaryLabel
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                    ),
                          ),
                          if (metaLabel != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              metaLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: colors.secondaryLabel,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: colors.secondaryLabel.withValues(alpha: 0.65),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
