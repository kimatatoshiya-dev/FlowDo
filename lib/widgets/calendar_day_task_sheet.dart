import 'package:flutter/material.dart';

import '../models/flowdo_calendar.dart';
import '../theme/app_theme.dart';
import '../utils/date_formatter.dart';
import 'task_completion_toggle.dart';

/// カレンダー日付タップ時の BottomSheet
class CalendarDayTaskSheet extends StatelessWidget {
  const CalendarDayTaskSheet({
    super.key,
    required this.day,
    required this.entries,
    required this.onToggleTask,
    required this.isRemoving,
    required this.showCompletedStyle,
  });

  final DateTime day;
  final List<FlowDoCalendarTaskEntry> entries;
  final Future<void> Function(int taskId) onToggleTask;
  final bool Function(int taskId) isRemoving;
  final bool Function(int taskId) showCompletedStyle;

  static Future<void> show(
    BuildContext context, {
    required DateTime day,
    required List<FlowDoCalendarTaskEntry> entries,
    required Future<void> Function(int taskId) onToggleTask,
    required bool Function(int taskId) isRemoving,
    required bool Function(int taskId) showCompletedStyle,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => CalendarDayTaskSheet(
        day: day,
        entries: entries,
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
    final sheetHeight = (entries.length * 52.0 + 120).clamp(220.0, screenHeight * 0.72);
    final title = formatCalendarDayTitle(day);

    final remainingCount = entries
        .where(
          (entry) =>
              !showCompletedStyle(entry.taskId) &&
              !isRemoving(entry.taskId),
        )
        .length;

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
              const SizedBox(height: 14),
              Expanded(
                child: entries.isEmpty
                    ? Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          'タスクはありません',
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
                          final removing = isRemoving(entry.taskId);

                          return AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                            alignment: Alignment.topCenter,
                            child: removing
                                ? const SizedBox.shrink()
                                : _CalendarTaskRow(
                                    entry: entry,
                                    completed:
                                        showCompletedStyle(entry.taskId),
                                    onToggle: () =>
                                        onToggleTask(entry.taskId),
                                  ),
                          );
                        },
                      ),
              ),
              if (entries.isNotEmpty) ...[
                const SizedBox(height: 8),
                Divider(
                  height: 1,
                  color: colors.separator.withValues(alpha: 0.8),
                ),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarTaskRow extends StatelessWidget {
  const _CalendarTaskRow({
    required this.entry,
    required this.completed,
    required this.onToggle,
  });

  final FlowDoCalendarTaskEntry entry;
  final bool completed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;

    return SizedBox(
      height: 52,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          TaskCompletionToggle(
            completed: completed,
            onTap: onToggle,
          ),
          const SizedBox(width: 10),
          Text(
            calendarTaskKindEmoji(entry.kind),
            style: const TextStyle(fontSize: 16, height: 1),
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
              child: Text.rich(
                TextSpan(
                  children: [
                    if (entry.reminderTime != null) ...[
                      TextSpan(
                        text:
                            '${DateFormatter.formatCalendarTaskTime(entry.reminderTime!)} ',
                      ),
                    ],
                    TextSpan(text: entry.title),
                  ],
                ),
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
