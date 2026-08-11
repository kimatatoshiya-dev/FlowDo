import 'package:flutter/material.dart';

import '../models/today_focus.dart';
import '../theme/app_theme.dart';
import 'flowdo_icons.dart';
import 'task_completion_toggle.dart';

/// 重要＆期限が近いタスクをその場で処理する BottomSheet
class TodayFocusTaskSheet extends StatelessWidget {
  const TodayFocusTaskSheet({
    super.key,
    required this.sections,
    required this.onToggleTask,
    required this.isRemoving,
    required this.showCompletedStyle,
  });

  static const rowHeight = 52.0;
  static const visibleRows = 7.5;
  static const subtitle = '今日優先して終わらせたいタスクです';

  final List<TodayFocusSectionData> sections;
  final Future<void> Function(int taskId) onToggleTask;
  final bool Function(int taskId) isRemoving;
  final bool Function(int taskId) showCompletedStyle;

  static Future<void> show(
    BuildContext context, {
    required List<TodayFocusSectionData> sections,
    required Future<void> Function(int taskId) onToggleTask,
    required bool Function(int taskId) isRemoving,
    required bool Function(int taskId) showCompletedStyle,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => TodayFocusTaskSheet(
        sections: sections,
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
    final sheetHeight =
        (rowHeight * visibleRows + 132).clamp(380.0, screenHeight * 0.78);

    final entries = flattenTodayFocusSections(sections);
    final remainingCount = countRemainingTodayFocusTasks(
      entries,
      showCompletedStyle: showCompletedStyle,
      isRemoving: isRemoving,
    );

    return SafeArea(
      child: SizedBox(
        height: sheetHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '重要＆期限が近いタスク',
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
                        separatorBuilder: (_, _) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          final removing = isRemoving(entry.task.taskId);

                          return AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                            alignment: Alignment.topCenter,
                            child: removing
                                ? const SizedBox.shrink()
                                : _TaskProcessRow(
                                    entry: entry,
                                    completed:
                                        showCompletedStyle(entry.task.taskId),
                                    onToggle: () =>
                                        onToggleTask(entry.task.taskId),
                                  ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              Divider(height: 1, color: colors.separator.withValues(alpha: 0.8)),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  '残り $remainingCount件',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.secondaryLabel.withValues(alpha: 0.85),
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// BottomSheet 下部ステータス用の残件数
int countRemainingTodayFocusTasks(
  List<TodayFocusListEntry> entries, {
  required bool Function(int taskId) showCompletedStyle,
  required bool Function(int taskId) isRemoving,
}) {
  return entries
      .where(
        (entry) =>
            !showCompletedStyle(entry.task.taskId) &&
            !isRemoving(entry.task.taskId),
      )
      .length;
}

class _TaskProcessRow extends StatelessWidget {
  const _TaskProcessRow({
    required this.entry,
    required this.completed,
    required this.onToggle,
  });

  final TodayFocusListEntry entry;
  final bool completed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;

    return SizedBox(
      height: TodayFocusTaskSheet.rowHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          TaskCompletionToggle(
            completed: completed,
            onTap: onToggle,
          ),
          const SizedBox(width: 10),
          TodayFocusLeadingIcon(
            kind: entry.kind,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    height: 1.35,
                    color: completed
                        ? colors.secondaryLabel
                        : Theme.of(context).colorScheme.onSurface,
                    decoration:
                        completed ? TextDecoration.lineThrough : null,
                    decorationColor: colors.secondaryLabel,
                  ),
              child: Text(
                entry.task.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
