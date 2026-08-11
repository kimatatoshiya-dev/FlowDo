import 'package:flutter/material.dart';

import '../models/category_item.dart';
import '../models/task.dart';
import '../models/task_priority.dart';
import '../theme/app_theme.dart';
import '../utils/date_formatter.dart';
import 'inbox_promote_pending.dart';
import 'registration_feedback.dart';

/// タスク1行分のリストタイル
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.category,
    required this.showCompletedStyle,
    required this.isRemoving,
    this.isLayoutHighlight = false,
    this.isLayoutAnimating = false,
    this.isRegistrationFeedback = false,
    this.isInboxPromotePending = false,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onDismissDelete,
    required this.onCategoryTap,
    required this.onPriorityTap,
    required this.onDueDateTap,
    required this.onFavoriteTap,
    this.showDivider = true,
    this.showCompletionToggle = true,
    this.showMetaChips = true,
    this.openEditOnRowTap = false,
    this.isCompletedList = false,
    this.enableInboxPromoteSwipe = false,
    this.onPromoteSwipe,
    this.categoryChipTooltip,
  });
  final Task task;
  final CategoryItem category;
  final bool showCompletedStyle;
  final bool isRemoving;
  final bool isLayoutHighlight;
  final bool isLayoutAnimating;
  final bool isRegistrationFeedback;
  final bool isInboxPromotePending;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDismissDelete;
  final VoidCallback onCategoryTap;
  final VoidCallback onPriorityTap;
  final VoidCallback onDueDateTap;
  final VoidCallback onFavoriteTap;
  final bool showDivider;
  final bool showCompletionToggle;
  final bool showMetaChips;
  final bool openEditOnRowTap;
  final bool isCompletedList;
  final bool enableInboxPromoteSwipe;
  final Future<void> Function()? onPromoteSwipe;
  final String? categoryChipTooltip;

  bool get _useCompletedVisual => isCompletedList || task.isCompleted;

  bool get _isImportantTask => task.isFavorite && !_useCompletedVisual;

  static const _importantAccent = Color(0xFFFF9500);

  EdgeInsets get _contentPadding => _useCompletedVisual
      ? const EdgeInsets.fromLTRB(10, 5, 4, 5)
      : const EdgeInsets.fromLTRB(12, 7, 8, 7);

  double get _checkboxSize => _useCompletedVisual ? 20.0 : 24.0;

  double get _checkboxIconSize => _useCompletedVisual ? 14.0 : 16.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey(task.id),
      direction: enableInboxPromoteSwipe
          ? DismissDirection.horizontal
          : DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        if (enableInboxPromoteSwipe &&
            direction == DismissDirection.startToEnd) {
          await onPromoteSwipe?.call();
          return false;
        }

        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('タスクを削除'),
            content: Text('「${task.title}」を削除しますか？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('削除'),
              ),
            ],
          ),
        );
        return confirmed ?? false;
      },
      background: enableInboxPromoteSwipe
          ? Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20),
              color: category.color.withValues(alpha: 0.18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_forward, color: category.color, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${category.name}へ',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: category.color,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            )
          : Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: colorScheme.errorContainer,
              child: Icon(
                Icons.delete_outline,
                color: colorScheme.onErrorContainer,
              ),
            ),
      secondaryBackground: enableInboxPromoteSwipe
          ? Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: colorScheme.errorContainer,
              child: Icon(
                Icons.delete_outline,
                color: colorScheme.onErrorContainer,
              ),
            )
          : null,
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          onDismissDelete();
        }
      },
      child: AnimatedOpacity(
        opacity: isRemoving || isLayoutAnimating ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        child: AnimatedSlide(
          offset: isLayoutAnimating ? const Offset(0, -0.06) : Offset.zero,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: InboxPromotePendingWrapper(
            enabled: isInboxPromotePending,
            child: RegistrationFeedbackWrapper(
            enabled: isRegistrationFeedback,
            child: AnimatedScale(
            scale: isRemoving || isLayoutAnimating ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: Stack(
              children: [
                if (isLayoutHighlight)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                Column(
            children: [
              Material(
                color: _useCompletedVisual
                    ? colors.completedTaskSurface
                    : _isImportantTask
                        ? _importantAccent.withValues(alpha: 0.08)
                        : Colors.transparent,
                borderRadius: isCompletedList
                    ? BorderRadius.circular(10)
                    : BorderRadius.zero,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 3,
                        decoration: BoxDecoration(
                          color: _useCompletedVisual
                              ? category.color.withValues(alpha: 0.45)
                              : _isImportantTask
                                  ? _importantAccent
                                  : category.color,
                          borderRadius: isCompletedList
                              ? const BorderRadius.horizontal(
                                  left: Radius.circular(10),
                                )
                              : BorderRadius.zero,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: _contentPadding,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showCompletionToggle)
                                Padding(
                                  padding: EdgeInsets.only(
                                    top: _useCompletedVisual ? 1 : 2,
                                  ),
                                  child: GestureDetector(
                                    onTap: onToggle,
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      curve: Curves.easeOut,
                                      width: _checkboxSize,
                                      height: _checkboxSize,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: showCompletedStyle
                                            ? colorScheme.primary.withValues(
                                                alpha: _useCompletedVisual
                                                    ? 0.75
                                                    : 1,
                                              )
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: showCompletedStyle
                                              ? colorScheme.primary.withValues(
                                                  alpha: _useCompletedVisual
                                                      ? 0.75
                                                      : 1,
                                                )
                                              : colors.secondaryLabel,
                                          width: 2,
                                        ),
                                      ),
                                      child: showCompletedStyle
                                          ? Icon(
                                              Icons.check,
                                              size: _checkboxIconSize,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                              if (showCompletionToggle)
                                SizedBox(
                                  width: _useCompletedVisual ? 10 : 12,
                                ),
                              Expanded(
                                child: openEditOnRowTap
                                    ? InkWell(
                                        onTap: onEdit,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 2,
                                          ),
                                          child: _buildTaskContent(
                                            context,
                                            colors,
                                            colorScheme,
                                          ),
                                        ),
                                      )
                                    : _buildTaskContent(
                                        context,
                                        colors,
                                        colorScheme,
                                      ),
                              ),
                              IconButton(
                                tooltip: task.isFavorite
                                    ? '重要タスクを解除'
                                    : '重要タスクにする',
                                icon: Icon(
                                  task.isFavorite
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  size: _useCompletedVisual ? 20 : 24,
                                  color: task.isFavorite
                                      ? _importantAccent.withValues(
                                          alpha: _useCompletedVisual ? 0.65 : 1,
                                        )
                                      : _useCompletedVisual
                                          ? colors.secondaryLabel
                                          : null,
                                ),
                                onPressed: onFavoriteTap,
                                visualDensity: VisualDensity.compact,
                                padding: _useCompletedVisual
                                    ? const EdgeInsets.all(4)
                                    : null,
                                constraints: _useCompletedVisual
                                    ? const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (showDivider && !isCompletedList)
                Divider(height: 1, indent: 16, color: colors.separator),
            ],
          ),
              ],
            ),
          ),
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskContent(
    BuildContext context,
    FlowDoColors colors,
    ColorScheme colorScheme,
  ) {
    final useMutedCompleted = isCompletedList;
    final showStrike = useMutedCompleted || showCompletedStyle;
    final titleColor = useMutedCompleted
        ? colors.secondaryLabel.withValues(alpha: 0.9)
        : showCompletedStyle
            ? colors.secondaryLabel
            : colorScheme.onSurface;

    final title = AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            decoration: showStrike ? TextDecoration.lineThrough : null,
            color: titleColor,
            fontWeight: FontWeight.w500,
            fontSize: useMutedCompleted ? 15 : null,
            height: useMutedCompleted ? 1.3 : null,
          ) ??
          const TextStyle(),
      child: Text(task.title),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        openEditOnRowTap
            ? title
            : GestureDetector(onTap: onEdit, child: title),
        if (useMutedCompleted && task.completedAt != null) ...[
          const SizedBox(height: 4),
          Text(
            '完了 ${DateFormatter.formatDateTime(task.completedAt!)}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.secondaryLabel.withValues(alpha: 0.75),
                  fontSize: 11,
                  height: 1.2,
                ),
          ),
        ],
        if (showMetaChips) ...[
          SizedBox(height: useMutedCompleted ? 4 : 5),
          Row(
            children: [
              _MetaTapChip(
                label: category.name,
                tooltip: categoryChipTooltip ?? category.name,
                color: useMutedCompleted
                    ? category.color.withValues(alpha: 0.55)
                    : category.color,
                onTap: onCategoryTap,
                compact: useMutedCompleted,
                fixedWidth: useMutedCompleted ? 76 : 84,
              ),
              SizedBox(width: useMutedCompleted ? 5 : 6),
              _MetaTapChip(
                label: TaskPriorityStars.label(task.priorityStars),
                color: _priorityChipColor(task.priorityStars, useMutedCompleted),
                backgroundColor:
                    _priorityChipBackground(task.priorityStars, useMutedCompleted),
                onTap: onPriorityTap,
                compact: useMutedCompleted,
              ),
              SizedBox(width: useMutedCompleted ? 5 : 6),
              Expanded(
                child: _MetaTapChip(
                  label: task.dueDate == null
                      ? DateFormatter.noDueDateLabel
                      : DateFormatter.formatDueDate(task.dueDate!),
                  color: task.dueDate == null
                      ? colors.secondaryLabel.withValues(
                          alpha: useMutedCompleted ? 0.65 : 1,
                        )
                      : task.isOverdue
                          ? colorScheme.error.withValues(
                              alpha: useMutedCompleted ? 0.65 : 1,
                            )
                          : task.isDueToday
                              ? const Color(0xFFFF9500).withValues(
                                  alpha: useMutedCompleted ? 0.65 : 1,
                                )
                              : colors.secondaryLabel.withValues(
                                  alpha: useMutedCompleted ? 0.65 : 1,
                                ),
                  backgroundColor: _dueChipBackground(
                    task: task,
                    colors: colors,
                    colorScheme: colorScheme,
                    useMutedCompleted: useMutedCompleted,
                  ),
                  icon: Icons.event_outlined,
                  onTap: onDueDateTap,
                  compact: useMutedCompleted,
                  expand: true,
                  denseHorizontal: true,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Color _priorityChipColor(int stars, bool muted) {
    final colors = TaskPriorityStars.chipColors(stars);
    return muted ? colors.foreground.withValues(alpha: 0.65) : colors.foreground;
  }

  Color _priorityChipBackground(int stars, bool muted) {
    final colors = TaskPriorityStars.chipColors(stars);
    if (muted) {
      return colors.foreground.withValues(alpha: 0.04);
    }
    return colors.background;
  }

  Color _dueChipBackground({
    required Task task,
    required FlowDoColors colors,
    required ColorScheme colorScheme,
    required bool useMutedCompleted,
  }) {
    if (task.dueDate == null) {
      return colors.secondaryLabel.withValues(
        alpha: useMutedCompleted ? 0.04 : 0.06,
      );
    }
    if (task.isOverdue) {
      return colorScheme.error.withValues(
        alpha: useMutedCompleted ? 0.07 : 0.09,
      );
    }
    if (task.isDueToday) {
      return const Color(0xFFFF9500).withValues(
        alpha: useMutedCompleted ? 0.07 : 0.09,
      );
    }
    return colors.secondaryLabel.withValues(
      alpha: useMutedCompleted ? 0.04 : 0.06,
    );
  }

}

class _MetaTapChip extends StatelessWidget {
  const _MetaTapChip({
    required this.label,
    required this.onTap,
    this.color,
    this.backgroundColor,
    this.icon,
    this.compact = false,
    this.fixedWidth,
    this.expand = false,
    this.tooltip,
    this.denseHorizontal = false,
  });

  final String label;
  final VoidCallback onTap;
  final Color? color;
  final Color? backgroundColor;
  final IconData? icon;
  final bool compact;
  final double? fixedWidth;
  final bool expand;
  final String? tooltip;
  final bool denseHorizontal;

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? Theme.of(context).colorScheme.outline;
    final verticalPadding = compact ? 3.0 : 4.0;
    final horizontalPadding = denseHorizontal
        ? (compact ? 5.0 : 6.0)
        : (compact ? 7.0 : 8.0);

    Widget labelWidget = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: chipColor,
            fontWeight: FontWeight.w600,
            fontSize: compact ? 10 : null,
            height: 1.2,
          ),
    );

    if (fixedWidth != null) {
      labelWidget = SizedBox(width: fixedWidth, child: labelWidget);
    } else if (expand) {
      labelWidget = Flexible(child: labelWidget);
    }

    final chip = Material(
      color: backgroundColor ?? chipColor.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: compact ? 11 : 12, color: chipColor),
                SizedBox(width: compact ? 3 : 4),
              ],
              labelWidget,
            ],
          ),
        ),
      ),
    );

    final fullName = tooltip ?? label;
    if (tooltip != null) {
      return Tooltip(
        message: fullName,
        triggerMode: TooltipTriggerMode.tap,
        showDuration: const Duration(seconds: 2),
        waitDuration: Duration.zero,
        child: chip,
      );
    }

    return chip;
  }
}

/// Inbox（追加したタスク）エリアの案内バナー
class InboxGuidanceBanner extends StatelessWidget {
  const InboxGuidanceBanner({super.key});

  static const message =
      '👇 次はここでカテゴリー・期限・優先度を決めて、タスクリストへ移動しましょう。';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = Theme.of(context).extension<FlowDoColors>()!;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.secondaryLabel,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}

/// iOS 風のグループ化リスト
class GroupedTaskList extends StatelessWidget {
  const GroupedTaskList({
    super.key,
    required this.title,
    required this.tasks,
    required this.categories,
    required this.showCompletedStyle,
    required this.isRemoving,
    this.isLayoutHighlight,
    this.isLayoutAnimating,
    this.isRegistrationFeedback,
    this.isInboxPromotePending,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onDismissDelete,
    required this.onCategoryTap,
    required this.onPriorityTap,
    required this.onDueDateTap,
    required this.onFavoriteTap,
    this.showCompletionToggle = true,
    this.showMetaChips = true,
    this.openEditOnRowTap = false,
    this.isCompletedList = false,
    this.isInboxList = false,
    this.showInboxGuidance = false,
    this.onPromoteTask,
  });

  final String title;
  final List<Task> tasks;
  final List<CategoryItem> categories;
  final bool Function(Task task) showCompletedStyle;
  final bool Function(Task task) isRemoving;
  final bool Function(Task task)? isLayoutHighlight;
  final bool Function(Task task)? isLayoutAnimating;
  final bool Function(Task task)? isRegistrationFeedback;
  final bool Function(Task task)? isInboxPromotePending;
  final void Function(Task task) onToggle;
  final void Function(Task task) onEdit;
  final void Function(Task task) onDelete;
  final void Function(Task task) onDismissDelete;
  final void Function(Task task) onCategoryTap;
  final void Function(Task task) onPriorityTap;
  final void Function(Task task) onDueDateTap;
  final void Function(Task task) onFavoriteTap;
  final bool showCompletionToggle;
  final bool showMetaChips;
  final bool openEditOnRowTap;
  final bool isCompletedList;
  final bool isInboxList;
  final bool showInboxGuidance;
  final Future<void> Function(Task task)? onPromoteTask;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();

    final colors = Theme.of(context).extension<FlowDoColors>()!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.secondaryLabel,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
          if (showInboxGuidance) const InboxGuidanceBanner(),
          if (isCompletedList)
            Column(
              children: [
                for (var i = 0; i < tasks.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i < tasks.length - 1 ? 4 : 0,
                    ),
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      alignment: Alignment.topCenter,
                      child: TaskTile(
                        task: tasks[i],
                        category: resolveCategory(
                          tasks[i].categoryId,
                          categories,
                        ),
                        showCompletedStyle: showCompletedStyle(tasks[i]),
                        isRemoving: isRemoving(tasks[i]),
                        isLayoutHighlight:
                            isLayoutHighlight?.call(tasks[i]) ?? false,
                        isLayoutAnimating:
                            isLayoutAnimating?.call(tasks[i]) ?? false,
                        isRegistrationFeedback:
                            isRegistrationFeedback?.call(tasks[i]) ?? false,
                        isInboxPromotePending:
                            isInboxPromotePending?.call(tasks[i]) ?? false,
                        showCompletionToggle: showCompletionToggle,
                        showMetaChips: showMetaChips,
                        openEditOnRowTap: openEditOnRowTap,
                        isCompletedList: true,
                        onToggle: () => onToggle(tasks[i]),
                        onEdit: () => onEdit(tasks[i]),
                        onDelete: () => onDelete(tasks[i]),
                        onDismissDelete: () => onDismissDelete(tasks[i]),
                        onCategoryTap: () => onCategoryTap(tasks[i]),
                        onPriorityTap: () => onPriorityTap(tasks[i]),
                        onDueDateTap: () => onDueDateTap(tasks[i]),
                        onFavoriteTap: () => onFavoriteTap(tasks[i]),
                        showDivider: false,
                      ),
                    ),
                  ),
              ],
            )
          else
            Container(
              decoration: BoxDecoration(
                color: colors.groupedSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < tasks.length; i++)
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      alignment: Alignment.topCenter,
                      child: TaskTile(
                        task: tasks[i],
                        category: resolveCategory(
                          tasks[i].categoryId,
                          categories,
                        ),
                        showCompletedStyle: showCompletedStyle(tasks[i]),
                        isRemoving: isRemoving(tasks[i]),
                        isLayoutHighlight:
                            isLayoutHighlight?.call(tasks[i]) ?? false,
                        isLayoutAnimating:
                            isLayoutAnimating?.call(tasks[i]) ?? false,
                        isRegistrationFeedback:
                            isRegistrationFeedback?.call(tasks[i]) ?? false,
                        isInboxPromotePending:
                            isInboxPromotePending?.call(tasks[i]) ?? false,
                        showCompletionToggle: showCompletionToggle,
                        showMetaChips: showMetaChips,
                        openEditOnRowTap: openEditOnRowTap,
                        enableInboxPromoteSwipe:
                            isInboxList && onPromoteTask != null,
                        onPromoteSwipe: isInboxList && onPromoteTask != null
                            ? () => onPromoteTask!(tasks[i])
                            : null,
                        categoryChipTooltip:
                            isInboxList ? 'リストへ移動' : null,
                        onToggle: () => onToggle(tasks[i]),
                        onEdit: () => onEdit(tasks[i]),
                        onDelete: () => onDelete(tasks[i]),
                        onDismissDelete: () => onDismissDelete(tasks[i]),
                        onCategoryTap: () => onCategoryTap(tasks[i]),
                        onPriorityTap: () => onPriorityTap(tasks[i]),
                        onDueDateTap: () => onDueDateTap(tasks[i]),
                        onFavoriteTap: () => onFavoriteTap(tasks[i]),
                        showDivider: i < tasks.length - 1,
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
