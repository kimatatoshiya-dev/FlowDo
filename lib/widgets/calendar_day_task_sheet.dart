import 'package:flutter/material.dart';

import '../models/flowdo_calendar.dart';
import '../theme/app_theme.dart';
import '../utils/date_formatter.dart';
import 'task_completion_toggle.dart';

/// カレンダー日付タップ時 — その日のタスク一覧 BottomSheet
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

  static const sheetHeightFactor = 0.88;
  static const rowHeight = 52.0;

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
      isDismissible: true,
      enableDrag: true,
      showDragHandle: false,
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
    final visibleEntries = entries
        .where((entry) => !isRemoving(entry.taskId))
        .toList(growable: false);
    final title = formatCalendarDayTitle(day);

    return FractionallySizedBox(
      heightFactor: sheetHeightFactor,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SheetDragHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                ),
              ),
              Expanded(
                child: visibleEntries.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            entries.isEmpty
                                ? 'タスクはありません'
                                : '残りのタスクはありません',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: colors.secondaryLabel),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                        itemCount: visibleEntries.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final entry = visibleEntries[index];
                          return _DayTaskRow(
                            entry: entry,
                            completed: showCompletedStyle(entry.taskId),
                            onToggle: () => onToggleTask(entry.taskId),
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

class _SheetDragHandle extends StatelessWidget {
  const _SheetDragHandle();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Container(
          width: 36,
          height: 5,
          decoration: BoxDecoration(
            color: colorScheme.onSurface.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
      ),
    );
  }
}

class _DayTaskRow extends StatelessWidget {
  const _DayTaskRow({
    required this.entry,
    required this.completed,
    required this.onToggle,
  });

  final FlowDoCalendarTaskEntry entry;
  final bool completed;
  final VoidCallback onToggle;

  String? get _timeLabel {
    if (entry.reminderTime == null) return null;
    return DateFormatter.formatReminderTime(entry.reminderTime!);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;
    final timeLabel = _timeLabel;

    return SizedBox(
      height: CalendarDayTaskSheet.rowHeight,
      child: Row(
        children: [
          TaskCompletionToggle(
            completed: completed,
            onTap: onToggle,
          ),
          const SizedBox(width: 12),
          _CategoryColorDot(
            color: Color(entry.categoryColorValue),
            completed: completed,
          ),
          const SizedBox(width: 12),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (timeLabel != null) ...[
            const SizedBox(width: 16),
            Text(
              timeLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.secondaryLabel,
                    fontWeight: FontWeight.w500,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ],
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
      width: completed ? 8 : 9,
      height: completed ? 8 : 9,
      decoration: BoxDecoration(
        color: completed ? color.withValues(alpha: 0.45) : color,
        shape: BoxShape.circle,
      ),
    );
  }
}
