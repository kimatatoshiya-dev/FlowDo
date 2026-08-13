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
    final summary = CalendarDaySheetSummary.fromEntries(entries);
    final visibleEntries = entries
        .where((entry) => !isRemoving(entry.taskId))
        .toList(growable: false);
    const headerHeight = 118.0;
    const rowHeight = 64.0;
    final sheetHeight = (headerHeight + visibleEntries.length * rowHeight + 16)
        .clamp(240.0, screenHeight * 0.78);
    final title = formatCalendarDayTitle(day);

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
              if (summary.hasAny) ...[
                const SizedBox(height: 12),
                _CalendarDaySummaryRow(summary: summary),
              ],
              const SizedBox(height: 14),
              Expanded(
                child: visibleEntries.isEmpty
                    ? Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          entries.isEmpty ? 'タスクはありません' : '残りのタスクはありません',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colors.secondaryLabel,
                                  ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: visibleEntries.length,
                        itemBuilder: (context, index) {
                          final entry = visibleEntries[index];
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index < visibleEntries.length - 1 ? 6 : 0,
                            ),
                            child: _CalendarTaskRow(
                              entry: entry,
                              completed: showCompletedStyle(entry.taskId),
                              onToggle: () => onToggleTask(entry.taskId),
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

class _CalendarDaySummaryRow extends StatelessWidget {
  const _CalendarDaySummaryRow({required this.summary});

  final CalendarDaySheetSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        if (summary.dueTodayCount > 0)
          _CalendarSummaryChip(
            emoji: '🔥',
            label: '今日',
            count: summary.dueTodayCount,
            colors: colors,
          ),
        if (summary.importantCount > 0)
          _CalendarSummaryChip(
            emoji: '📌',
            label: '固定',
            count: summary.importantCount,
            colors: colors,
          ),
        if (summary.scheduledCount > 0)
          _CalendarSummaryChip(
            emoji: '🗓️',
            label: '7日以内',
            count: summary.scheduledCount,
            colors: colors,
          ),
      ],
    );
  }
}

class _CalendarSummaryChip extends StatelessWidget {
  const _CalendarSummaryChip({
    required this.emoji,
    required this.label,
    required this.count,
    required this.colors,
  });

  final String emoji;
  final String label;
  final int count;
  final FlowDoColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.completedTaskSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$emoji '),
            TextSpan(
              text: label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.secondaryLabel,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            TextSpan(
              text: '  $count件',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.secondaryLabel.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
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
    final subtitle = entry.reminderTime == null
        ? '期限なし'
        : DateFormatter.formatReminderTimeChip(entry.reminderTime!);

    return SizedBox(
      height: 64,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: TaskCompletionToggle(
              completed: completed,
              onTap: onToggle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _CategoryColorDot(
                      color: Color(entry.categoryColorValue),
                      completed: completed,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                              height: 1.25,
                              fontWeight: FontWeight.w500,
                              color: completed
                                  ? colors.secondaryLabel
                                  : Theme.of(context).colorScheme.onSurface,
                              decoration:
                                  completed ? TextDecoration.lineThrough : null,
                              decorationColor: colors.secondaryLabel,
                            ),
                        child: Text(
                          entry.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          height: 1.2,
                          color: completed
                              ? colors.secondaryLabel.withValues(alpha: 0.75)
                              : colors.secondaryLabel,
                        ),
                    child: Text(subtitle),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryColorDot extends StatelessWidget {
  const _CategoryColorDot({
    required this.color,
    required this.completed,
  });

  final Color color;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: completed ? 7 : 8,
      height: completed ? 7 : 8,
      margin: EdgeInsets.only(top: completed ? 7 : 6),
      decoration: BoxDecoration(
        color: completed ? color.withValues(alpha: 0.45) : color,
        shape: BoxShape.circle,
      ),
    );
  }
}
