import 'package:flutter/material.dart';

import '../models/today_focus.dart';
import '../theme/app_theme.dart';
import 'flowdo_icons.dart';
import 'task_completion_toggle.dart';

/// ダッシュボード 📌🔥🗓️ タップ時のタスク一覧 BottomSheet
class DashboardSummaryTaskSheet extends StatelessWidget {
  const DashboardSummaryTaskSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.entries,
    required this.onTaskTap,
    required this.onToggleTask,
    required this.isRemoving,
    required this.showCompletedStyle,
  });

  static const sheetHeightFactor = 0.75;
  static const rowHeight = 52.0;

  final String title;
  final String subtitle;
  final List<TodayFocusListEntry> entries;
  final ValueChanged<int> onTaskTap;
  final Future<void> Function(int taskId) onToggleTask;
  final bool Function(int taskId) isRemoving;
  final bool Function(int taskId) showCompletedStyle;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<TodayFocusListEntry> entries,
    required ValueChanged<int> onTaskTap,
    required Future<void> Function(int taskId) onToggleTask,
    required bool Function(int taskId) isRemoving,
    required bool Function(int taskId) showCompletedStyle,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DashboardSummaryTaskSheet(
        title: title,
        subtitle: subtitle,
        entries: entries,
        onTaskTap: onTaskTap,
        onToggleTask: onToggleTask,
        isRemoving: isRemoving,
        showCompletedStyle: showCompletedStyle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final sheetHeight = screenHeight * sheetHeightFactor;

    return SafeArea(
      child: SizedBox(
        height: sheetHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12.5,
                      height: 1.35,
                      color: colors.secondaryLabel,
                    ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: entries.isEmpty
                    ? Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          '該当するタスクはありません',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colors.secondaryLabel,
                                  ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          final removing = isRemoving(entry.task.taskId);
                          if (removing) return const SizedBox.shrink();

                          return _DashboardSummaryTaskRow(
                            entry: entry,
                            completed: showCompletedStyle(entry.task.taskId),
                            onToggle: () => onToggleTask(entry.task.taskId),
                            onTap: () => onTaskTap(entry.task.taskId),
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

class _DashboardSummaryTaskRow extends StatelessWidget {
  const _DashboardSummaryTaskRow({
    required this.entry,
    required this.completed,
    required this.onToggle,
    required this.onTap,
  });

  final TodayFocusListEntry entry;
  final bool completed;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;

    return Material(
      color: colors.groupedSurface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: DashboardSummaryTaskSheet.rowHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                TaskCompletionToggle(
                  completed: completed,
                  onTap: onToggle,
                ),
                const SizedBox(width: 12),
                TodayFocusLeadingIcon(kind: entry.kind),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          decoration:
                              completed ? TextDecoration.lineThrough : null,
                          color: completed
                              ? colors.secondaryLabel
                              : Theme.of(context).colorScheme.onSurface,
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
      ),
    );
  }
}
