import 'package:flutter/material.dart';

import '../models/category_item.dart';
import '../models/task.dart';
import '../models/task_priority.dart';
import '../models/task_sort_mode.dart';
import '../theme/app_theme.dart';
import '../utils/date_formatter.dart';
import 'inbox_promote_pending.dart';
import 'registration_feedback.dart';
import 'task_swipe_actions.dart';

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
    this.isInboxList = false,
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
  final bool isInboxList;
  final bool enableInboxPromoteSwipe;
  final Future<void> Function()? onPromoteSwipe;
  final String? categoryChipTooltip;

  static const categoryColorDotKey = ValueKey('task_category_color_dot');

  bool get _useCompletedVisual => isCompletedList || task.isCompleted;

  bool get _isPinnedTask => task.isFavorite && !_useCompletedVisual;

  static const _pinAccent = Color(0xFFFF9500);
  static const _flowDoBlue = Color(0xFF007AFF);
  static const _inboxUnorganizedFill = Color(0xFFF5F9FF);
  static const _inboxStyleDuration = Duration(milliseconds: 200);

  bool get _showInboxUnorganizedStyle =>
      isInboxList && !isCompletedList && task.isInboxUnorganized;

  Color _materialColor(FlowDoColors colors) {
    if (_useCompletedVisual) return colors.completedTaskSurface;
    if (_isPinnedTask && !_showInboxUnorganizedStyle) {
      return _pinAccent.withValues(alpha: 0.08);
    }
    if (_showInboxUnorganizedStyle) return _inboxUnorganizedFill;
    if (isInboxList) return colors.groupedSurface;
    return Colors.transparent;
  }

  double get _leftStripeWidth {
    if (_useCompletedVisual) return 3;
    if (isInboxList) return _showInboxUnorganizedStyle ? 3 : 0;
    return 3;
  }

  Color _leftStripeColor() {
    if (_useCompletedVisual) {
      return category.color.withValues(alpha: 0.45);
    }
    if (_isPinnedTask && !isInboxList) return _pinAccent;
    if (_showInboxUnorganizedStyle) return _flowDoBlue;
    if (isInboxList) return Colors.transparent;
    return category.color;
  }

  EdgeInsets get _contentPadding => _useCompletedVisual
      ? const EdgeInsets.fromLTRB(10, 4, 4, 4)
      : const EdgeInsets.fromLTRB(12, 5, 6, 5);

  double get _checkboxSize => _useCompletedVisual ? 20.0 : 24.0;

  double get _checkboxIconSize => _useCompletedVisual ? 14.0 : 16.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return TaskSwipeActions(
      key: ValueKey(task.id),
      enabled: !isRemoving && !isLayoutAnimating,
      onComplete: onToggle,
      onEdit: onEdit,
      onDismissDelete: onDismissDelete,
      confirmDelete: () => _confirmDelete(context, colorScheme),
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
                color: Colors.transparent,
                borderRadius: isCompletedList
                    ? BorderRadius.circular(10)
                    : BorderRadius.zero,
                child: AnimatedContainer(
                  duration: _inboxStyleDuration,
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: _materialColor(colors),
                    borderRadius: isCompletedList
                        ? BorderRadius.circular(10)
                        : BorderRadius.zero,
                  ),
                  child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AnimatedContainer(
                        duration: _inboxStyleDuration,
                        curve: Curves.easeOut,
                        width: _leftStripeWidth,
                        decoration: BoxDecoration(
                          color: _leftStripeWidth > 0
                              ? _leftStripeColor()
                              : Colors.transparent,
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
                                    top: _useCompletedVisual ? 0 : 1,
                                  ),
                                  child: GestureDetector(
                                    onTap: onToggle,
                                    child: AnimatedContainer(
                                      key: const ValueKey('task_completion_checkbox'),
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
                                            vertical: 1,
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
                                    ? '固定を解除'
                                    : '最上位へ固定',
                                icon: Text(
                                  '📌',
                                  style: TextStyle(
                                    fontSize: _useCompletedVisual ? 18 : 20,
                                    height: 1,
                                    color: task.isFavorite
                                        ? _pinAccent.withValues(
                                            alpha:
                                                _useCompletedVisual ? 0.65 : 1,
                                          )
                                        : _useCompletedVisual
                                            ? colors.secondaryLabel
                                            : colors.secondaryLabel
                                                .withValues(alpha: 0.55),
                                  ),
                                ),
                                onPressed: onFavoriteTap,
                                visualDensity: VisualDensity.compact,
                                padding: _useCompletedVisual
                                    ? const EdgeInsets.all(4)
                                    : const EdgeInsets.all(6),
                                constraints: _useCompletedVisual
                                    ? const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      )
                                    : const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
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

  Future<bool> _confirmDelete(
    BuildContext context,
    ColorScheme colorScheme,
  ) async {
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
      duration: _inboxStyleDuration,
      curve: Curves.easeOut,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            decoration: showStrike ? TextDecoration.lineThrough : null,
            color: titleColor,
            fontWeight: _showInboxUnorganizedStyle ? FontWeight.w600 : FontWeight.w500,
            fontSize: useMutedCompleted ? 15 : null,
            height: useMutedCompleted ? 1.3 : null,
          ) ??
          const TextStyle(),
      child: Text(task.title),
    );

    final titleRow = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CategoryColorDot(
          color: useMutedCompleted
              ? category.color.withValues(alpha: 0.55)
              : category.color,
          onTap: onCategoryTap,
          tooltip: categoryChipTooltip ?? category.name,
          compact: useMutedCompleted,
        ),
        SizedBox(width: useMutedCompleted ? 7 : 8),
        Expanded(
          child: openEditOnRowTap
              ? title
              : GestureDetector(onTap: onEdit, child: title),
        ),
        AnimatedSwitcher(
          duration: _inboxStyleDuration,
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeOut,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
              child: child,
            ),
          ),
          child: _showInboxUnorganizedStyle
              ? Container(
                  key: const ValueKey('inbox-unorganized-badge'),
                  margin: const EdgeInsets.only(left: 8, top: 1),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _flowDoBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '未整理',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _flowDoBlue,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('inbox-organized-badge')),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        titleRow,
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
          SizedBox(height: useMutedCompleted ? 3 : 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _MetaTapChip(
                label: TaskPriorityStars.label(task.priorityStars),
                color: _priorityChipColor(task.priorityStars, useMutedCompleted),
                backgroundColor:
                    _priorityChipBackground(task.priorityStars, useMutedCompleted),
                onTap: onPriorityTap,
                compact: useMutedCompleted,
              ),
              SizedBox(width: useMutedCompleted ? 4 : 5),
              Expanded(
                child: task.dueDate == null
                    ? _MetaTapChip(
                        label: DateFormatter.noDueDateLabel,
                        color: colors.secondaryLabel.withValues(
                          alpha: useMutedCompleted ? 0.65 : 1,
                        ),
                        backgroundColor: colors.secondaryLabel.withValues(
                          alpha: useMutedCompleted ? 0.04 : 0.06,
                        ),
                        icon: Icons.event_outlined,
                        onTap: onDueDateTap,
                        compact: useMutedCompleted,
                        expand: true,
                        denseHorizontal: true,
                      )
                    : _DueDateTapChip(
                        task: task,
                        useMutedCompleted: useMutedCompleted,
                        onTap: onDueDateTap,
                        compact: useMutedCompleted,
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
}

class _CategoryColorDot extends StatelessWidget {
  const _CategoryColorDot({
    required this.color,
    required this.onTap,
    required this.tooltip,
    required this.compact,
  });

  final Color color;
  final VoidCallback onTap;
  final String tooltip;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 7.0 : 8.0;

    return Semantics(
      label: tooltip,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: TaskTile.categoryColorDotKey,
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: EdgeInsets.only(top: compact ? 4 : 5),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DueDateTapChip extends StatelessWidget {
  const _DueDateTapChip({
    required this.task,
    required this.useMutedCompleted,
    required this.onTap,
    required this.compact,
  });

  final Task task;
  final bool useMutedCompleted;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final display = DateFormatter.buildTaskDueChipDisplay(
      dueDate: task.dueDate!,
      reminderTime: task.reminderTime,
    );
    final foreground = DateFormatter.dueDateChipForeground(
      display.urgency,
      colorScheme: colorScheme,
      secondaryLabel: colors.secondaryLabel,
      muted: useMutedCompleted,
    );
    final background = DateFormatter.dueDateChipBackground(
      display.urgency,
      colorScheme: colorScheme,
      secondaryLabel: colors.secondaryLabel,
      muted: useMutedCompleted,
    );
    final verticalPadding = compact ? 2.0 : 3.0;
    final horizontalPadding = compact ? 5.0 : 6.0;

    return Tooltip(
      message: display.tooltipLabel,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 2),
      waitDuration: Duration.zero,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: Text(
              display.inlineLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                    fontSize: compact ? 10 : 11,
                    height: 1.15,
                  ),
            ),
          ),
        ),
      ),
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
    this.maxLines = 1,
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
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? Theme.of(context).colorScheme.outline;
    final verticalPadding = compact ? 2.0 : 3.0;
    final horizontalPadding = denseHorizontal
        ? (compact ? 5.0 : 6.0)
        : (compact ? 6.0 : 7.0);

    Widget labelWidget = Text(
      label,
      maxLines: maxLines,
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
    this.enablePinnedReorder = false,
    this.onPinnedReorder,
    this.pinLayoutDeferredTaskIds = const {},
    this.showSectionTitle = true,
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
  final bool enablePinnedReorder;
  final void Function(List<Task> reorderedPinned)? onPinnedReorder;
  final Set<int> pinLayoutDeferredTaskIds;
  final bool showSectionTitle;

  TaskTile _taskTileFor(Task task, {required bool showDivider}) {
    return TaskTile(
      task: task,
      category: resolveCategory(task.categoryId, categories),
      showCompletedStyle: showCompletedStyle(task),
      isRemoving: isRemoving(task),
      isLayoutHighlight: isLayoutHighlight?.call(task) ?? false,
      isLayoutAnimating: isLayoutAnimating?.call(task) ?? false,
      isRegistrationFeedback: isRegistrationFeedback?.call(task) ?? false,
      isInboxPromotePending: isInboxPromotePending?.call(task) ?? false,
      showCompletionToggle: showCompletionToggle,
      showMetaChips: showMetaChips,
      openEditOnRowTap: openEditOnRowTap,
      isCompletedList: isCompletedList,
      isInboxList: isInboxList,
      enableInboxPromoteSwipe: isInboxList && onPromoteTask != null,
      onPromoteSwipe:
          isInboxList && onPromoteTask != null ? () => onPromoteTask!(task) : null,
      categoryChipTooltip: isInboxList ? 'グループを変更' : null,
      onToggle: () => onToggle(task),
      onEdit: () => onEdit(task),
      onDelete: () => onDelete(task),
      onDismissDelete: () => onDismissDelete(task),
      onCategoryTap: () => onCategoryTap(task),
      onPriorityTap: () => onPriorityTap(task),
      onDueDateTap: () => onDueDateTap(task),
      onFavoriteTap: () => onFavoriteTap(task),
      showDivider: showDivider,
    );
  }

  Widget _buildPinnedReorderRow(
    BuildContext context,
    FlowDoColors colors,
    Task task,
    int index,
    int pinnedCount,
    bool hasUnpinned,
  ) {
    return Material(
      key: ValueKey('pinned-reorder-${task.id}'),
      color: Colors.transparent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Tooltip(
              message: '長押しして並び替え',
              child: Padding(
                padding: const EdgeInsets.only(left: 2, top: 10),
                child: Icon(
                  Icons.swap_vert,
                  size: 22,
                  color: colors.secondaryLabel.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
          Expanded(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _taskTileFor(
                task,
                showDivider: index < pinnedCount - 1 || hasUnpinned,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingGroupedList(BuildContext context, FlowDoColors colors) {
    final (pinned, unpinned) = splitPinnedTasksForDisplay(
      tasks,
      pinLayoutDeferredTaskIds: pinLayoutDeferredTaskIds,
    );
    final canReorderPinned =
        enablePinnedReorder && pinned.length >= 2 && onPinnedReorder != null;

    return Container(
      decoration: BoxDecoration(
        color: colors.groupedSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (canReorderPinned)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: pinned.length,
              onReorder: (oldIndex, newIndex) {
                final next = List<Task>.from(pinned);
                if (newIndex > oldIndex) newIndex -= 1;
                next.insert(newIndex, next.removeAt(oldIndex));
                onPinnedReorder!(next);
              },
              itemBuilder: (context, index) => _buildPinnedReorderRow(
                context,
                colors,
                pinned[index],
                index,
                pinned.length,
                unpinned.isNotEmpty,
              ),
            )
          else
            for (var i = 0; i < pinned.length; i++)
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _taskTileFor(
                  pinned[i],
                  showDivider: i < pinned.length - 1 || unpinned.isNotEmpty,
                ),
              ),
          for (var i = 0; i < unpinned.length; i++)
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _taskTileFor(
                unpinned[i],
                showDivider: i < unpinned.length - 1,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();

    final colors = Theme.of(context).extension<FlowDoColors>()!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showSectionTitle)
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
            _buildPendingGroupedList(context, colors),
        ],
      ),
    );
  }
}
