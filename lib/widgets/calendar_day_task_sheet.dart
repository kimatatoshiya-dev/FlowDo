import 'package:flutter/material.dart';

import '../models/flowdo_calendar.dart';
import '../theme/app_theme.dart';
import '../utils/date_formatter.dart';
import 'daily_memo_editor.dart';
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
    this.memoText = '',
    this.onMemoChanged,
  });

  final DateTime day;
  final List<FlowDoCalendarTaskEntry> entries;
  final Future<void> Function(int taskId) onToggleTask;
  final bool Function(int taskId) isRemoving;
  final bool Function(int taskId) showCompletedStyle;
  final String memoText;
  final Future<void> Function(String text)? onMemoChanged;

  static const sheetHeightFactor = 0.88;
  static const rowHeight = 52.0;

  static Future<void> show(
    BuildContext context, {
    required DateTime day,
    required List<FlowDoCalendarTaskEntry> entries,
    required Future<void> Function(int taskId) onToggleTask,
    required bool Function(int taskId) isRemoving,
    required bool Function(int taskId) showCompletedStyle,
    String memoText = '',
    Future<void> Function(String text)? onMemoChanged,
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
        memoText: memoText,
        onMemoChanged: onMemoChanged,
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
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  children: [
                    Text(
                      '📝 今日メモ',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if (onMemoChanged == null)
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 96),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.groupedSurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          memoText.isEmpty
                              ? '今日の気付き・反省・アイデアを書きましょう'
                              : memoText,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    else
                      DailyMemoEditor(
                        initialText: memoText,
                        onSave: onMemoChanged!,
                        minHeight: 96,
                      ),
                    const SizedBox(height: 20),
                    if (visibleEntries.isEmpty)
                      Text(
                        entries.isEmpty
                            ? 'タスクはありません'
                            : '残りのタスクはありません',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: colors.secondaryLabel),
                      )
                    else
                      for (var i = 0; i < visibleEntries.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        _DayTaskRow(
                          entry: visibleEntries[i],
                          completed:
                              showCompletedStyle(visibleEntries[i].taskId),
                          onToggle: () =>
                              onToggleTask(visibleEntries[i].taskId),
                        ),
                      ],
                  ],
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
