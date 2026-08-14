import 'dart:async';

import 'package:flutter/material.dart';

import '../models/flowdo_calendar.dart';
import '../models/task.dart';
import '../models/task_repeat_type.dart';
import '../theme/app_theme.dart';
import '../utils/date_formatter.dart';
import '../widgets/today_memo_section.dart';
import '../widgets/task_completion_toggle.dart';

/// 時刻帯に応じた今日画面の挨拶
class TodayGreeting {
  const TodayGreeting({
    required this.headline,
    required this.message,
  });

  final String headline;
  final String message;

  /// 現在時刻から挨拶を判定する
  static TodayGreeting resolve(DateTime now) {
    final hour = now.hour;

    if (hour >= 5 && hour < 11) {
      return const TodayGreeting(
        headline: '🌅 おはようございます！',
        message: '今日も一歩ずつ進めていきましょう。',
      );
    }
    if (hour >= 11 && hour < 17) {
      return const TodayGreeting(
        headline: '☀️ こんにちは！',
        message: '今日の予定、順調ですか？',
      );
    }
    if (hour >= 17 && hour < 19) {
      return const TodayGreeting(
        headline: '🌇 お疲れさまです！',
        message: 'あと少し。無理せずいきましょう。',
      );
    }
    return const TodayGreeting(
      headline: '🌙 今日も一日お疲れさまでした。',
      message: '今日できたことを振り返ってみましょう。',
    );
  }
}

String formatTodayPageDateLabel(DateTime day) {
  return '${day.year}年${formatCalendarDayTitle(day)}';
}

/// 今日の予定 — 今日が期限の未完了タスク（時間順・時間なしは末尾）
List<Task> todayScheduleTasks({
  required List<Task> tasks,
  DateTime? referenceToday,
}) {
  final today = dateOnly(referenceToday ?? DateTime.now());
  final dueToday = tasks.where((task) {
    if (task.isCompleted || task.dueDate == null) return false;
    return isSameDay(dateOnly(task.dueDate!), today);
  }).toList(growable: false);

  int compareTimeOfDay(TimeOfDay a, TimeOfDay b) {
    final hourCompare = a.hour.compareTo(b.hour);
    if (hourCompare != 0) return hourCompare;
    return a.minute.compareTo(b.minute);
  }

  dueToday.sort((a, b) {
    final aHasTime = a.reminderTime != null;
    final bHasTime = b.reminderTime != null;
    if (aHasTime && bHasTime) {
      final timeCompare = compareTimeOfDay(a.reminderTime!, b.reminderTime!);
      if (timeCompare != 0) return timeCompare;
    } else if (aHasTime != bHasTime) {
      return aHasTime ? -1 : 1;
    }
    return a.title.compareTo(b.title);
  });

  return dueToday;
}

/// 今日の最重要 — 今日期限・📌重要・未完了の先頭1件
Task? todayTopPriorityTask({
  required List<Task> tasks,
  DateTime? referenceToday,
}) {
  final today = dateOnly(referenceToday ?? DateTime.now());
  final candidates = tasks.where((task) {
    if (task.isCompleted || !task.isFavorite || task.dueDate == null) {
      return false;
    }
    return isSameDay(dateOnly(task.dueDate!), today);
  }).toList();
  if (candidates.isEmpty) return null;

  candidates.sort((a, b) {
    final priorityCompare = b.priorityStars.compareTo(a.priorityStars);
    if (priorityCompare != 0) return priorityCompare;
    return a.title.compareTo(b.title);
  });
  return candidates.first;
}

/// 7日以内 — 明日〜7日後までの未完了タスク（今日は除外）
List<Task> todayWithin7DaysTasks({
  required List<Task> tasks,
  DateTime? referenceToday,
}) {
  final today = dateOnly(referenceToday ?? DateTime.now());
  final tomorrow = today.add(const Duration(days: 1));
  final weekEnd = today.add(const Duration(days: 7));

  final upcoming = tasks.where((task) {
    if (task.isCompleted || task.dueDate == null) return false;
    final due = dateOnly(task.dueDate!);
    return !due.isBefore(tomorrow) && !due.isAfter(weekEnd);
  }).toList();

  upcoming.sort((a, b) {
    final dueCompare = dateOnly(a.dueDate!).compareTo(dateOnly(b.dueDate!));
    if (dueCompare != 0) return dueCompare;
    return a.title.compareTo(b.title);
  });

  return upcoming;
}

int todayDaysUntilDue(Task task, DateTime referenceToday) {
  return dateOnly(task.dueDate!)
      .difference(dateOnly(referenceToday))
      .inDays;
}

/// 今日の達成率 — 今日期限タスクの完了数 ÷ 対象数
TodayAchievementStats todayAchievementStats({
  required List<Task> tasks,
  DateTime? referenceToday,
}) {
  final today = dateOnly(referenceToday ?? DateTime.now());
  final todayTasks = tasks.where((task) {
    if (task.dueDate == null) return false;
    return isSameDay(dateOnly(task.dueDate!), today);
  });

  var completedCount = 0;
  var totalCount = 0;
  for (final task in todayTasks) {
    totalCount++;
    if (task.isCompleted) completedCount++;
  }

  return TodayAchievementStats(
    completedCount: completedCount,
    totalCount: totalCount,
  );
}

class TodayAchievementStats {
  const TodayAchievementStats({
    required this.completedCount,
    required this.totalCount,
  });

  final int completedCount;
  final int totalCount;

  double get progress =>
      totalCount == 0 ? 0 : completedCount / totalCount;

  int get percent => (progress * 100).round();
}

/// Phase2-1 — 「今日」画面
class TodayPage extends StatelessWidget {
  const TodayPage({
    super.key,
    this.now,
    this.embedded = false,
    this.tasks = const [],
    this.onRoutineToggle,
    this.onToggleTask,
    this.onTaskEdit,
    this.showCompletedStyle,
    this.isRemoving,
    this.memoText = '',
    this.onMemoChanged,
  });

  /// テスト用。未指定時は [DateTime.now] を使用
  final DateTime? now;

  /// [FlowDoHomePage] の PageView 内に埋め込む場合は true
  final bool embedded;

  /// [FlowDoHomePage] の TaskRepository 由来タスク一覧
  final List<Task> tasks;

  /// ルーティンタスクの完了切替（未指定時は操作不可）
  final ValueChanged<Task>? onRoutineToggle;

  /// 通常タスクの完了切替（未指定時は操作不可）
  final Future<void> Function(Task task)? onToggleTask;

  /// タスクタイトルタップで編集
  final ValueChanged<Task>? onTaskEdit;

  /// 完了待機中のチェック表示
  final bool Function(Task task)? showCompletedStyle;

  /// 完了アニメーションでリストから消える直前
  final bool Function(Task task)? isRemoving;

  /// 表示日のメモ本文
  final String memoText;

  /// メモ自動保存
  final Future<void> Function(String text)? onMemoChanged;

  static const backgroundColor = Color(0xFFF5F5F7);
  static const flowDoBlue = Color(0xFF007AFF);
  static const horizontalPadding = 20.0;
  static const sectionSpacing = 24.0;
  static const cardRadius = 18.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;
    final referenceNow = now ?? DateTime.now();
    final greeting = TodayGreeting.resolve(referenceNow);
    final dateLabel = formatTodayPageDateLabel(referenceNow);
    final scheduleTasks = todayScheduleTasks(
      tasks: tasks,
      referenceToday: referenceNow,
    );
    final topPriorityTask = todayTopPriorityTask(
      tasks: tasks,
      referenceToday: referenceNow,
    );
    final within7DaysTasks = todayWithin7DaysTasks(
      tasks: tasks,
      referenceToday: referenceNow,
    );
    final achievement = todayAchievementStats(
      tasks: tasks,
      referenceToday: referenceNow,
    );
    final routineTasks = todayRoutineTasks(tasks: tasks);
    final showCompleted = showCompletedStyle;
    final removing = isRemoving;

    Widget buildTaskRow(
      Task task, {
      Widget? prefix,
      Widget? trailing,
      Future<void> Function()? onToggle,
    }) {
      return _TodayInteractiveTaskRow(
        task: task,
        completed: showCompleted?.call(task) ?? false,
        removing: removing?.call(task) ?? false,
        onToggle: onToggle,
        onTitleTap: onTaskEdit == null ? null : () => onTaskEdit!(task),
        prefix: prefix,
        trailing: trailing,
      );
    }

    final content = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        horizontalPadding,
        12,
        horizontalPadding,
        40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TodayHeader(
            greeting: greeting,
            dateLabel: dateLabel,
          ),
          const SizedBox(height: sectionSpacing),
          _TodaySectionCard(
            title: '🔥 今日の最重要',
            child: topPriorityTask == null
                ? _emptySectionMessage(
                    context,
                    colors,
                    '今日の最重要はありません',
                  )
                : buildTaskRow(
                    topPriorityTask,
                    onToggle: onToggleTask == null
                        ? null
                        : () => onToggleTask!(topPriorityTask),
                  ),
          ),
          const SizedBox(height: sectionSpacing),
          _TodaySectionCard(
            title: '🗓️ 今日の予定',
            child: scheduleTasks.isEmpty
                ? _emptySectionMessage(
                    context,
                    colors,
                    '今日の予定はありません',
                  )
                : Column(
                    children: [
                      for (var i = 0; i < scheduleTasks.length; i++) ...[
                        if (i > 0) _sectionDivider(colors),
                        buildTaskRow(
                          scheduleTasks[i],
                          onToggle: onToggleTask == null
                              ? null
                              : () => onToggleTask!(scheduleTasks[i]),
                          prefix: scheduleTasks[i].reminderTime == null
                              ? null
                              : Text(
                                  DateFormatter.formatReminderTime(
                                    scheduleTasks[i].reminderTime!,
                                  ),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: TodayPage.flowDoBlue,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                ),
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: sectionSpacing),
          _TodaySectionCard(
            title: '🗓️ 7日以内',
            child: within7DaysTasks.isEmpty
                ? _emptySectionMessage(
                    context,
                    colors,
                    '7日以内のタスクはありません',
                  )
                : Column(
                    children: [
                      for (var i = 0; i < within7DaysTasks.length; i++) ...[
                        if (i > 0) _sectionDivider(colors),
                        buildTaskRow(
                          within7DaysTasks[i],
                          onToggle: onToggleTask == null
                              ? null
                              : () => onToggleTask!(within7DaysTasks[i]),
                          trailing: Text(
                            'あと${todayDaysUntilDue(within7DaysTasks[i], referenceNow)}日',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontSize: 15,
                                  color: colors.secondaryLabel,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: sectionSpacing),
          _TodaySectionCard(
            title: '🔁 ルーティン',
            child: routineTasks.isEmpty
                ? _emptySectionMessage(
                    context,
                    colors,
                    'ルーティンはありません',
                  )
                : Column(
                    children: [
                      for (var i = 0; i < routineTasks.length; i++) ...[
                        if (i > 0) _sectionDivider(colors),
                        _TodayRoutineTaskRow(
                          task: routineTasks[i],
                          completed: DailyRoutineLogic.isCompletedToday(
                            routineTasks[i],
                            referenceNow,
                          ),
                          onToggle: onRoutineToggle == null
                              ? null
                              : () => onRoutineToggle!(routineTasks[i]),
                          onTitleTap: onTaskEdit == null
                              ? null
                              : () => onTaskEdit!(routineTasks[i]),
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: sectionSpacing),
          TodayMemoSection(
            memoText: memoText,
            onMemoChanged: onMemoChanged,
          ),
          const SizedBox(height: sectionSpacing),
          _TodayAchievementCard(progress: achievement.progress),
        ],
      ),
    );

    if (embedded) {
      return ColoredBox(
        color: backgroundColor,
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(child: content),
    );
  }

  static Widget _sectionDivider(FlowDoColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Divider(
        height: 1,
        thickness: 1,
        color: colors.separator.withValues(alpha: 0.65),
      ),
    );
  }

  static Widget _emptySectionMessage(
    BuildContext context,
    FlowDoColors colors,
    String message,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              color: colors.secondaryLabel,
            ),
      ),
    );
  }
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({
    required this.greeting,
    required this.dateLabel,
  });

  final TodayGreeting greeting;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting.headline,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                height: 1.25,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          greeting.message,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 16,
                height: 1.45,
                color: colors.secondaryLabel.withValues(alpha: 0.92),
                fontWeight: FontWeight.w400,
              ),
        ),
        const SizedBox(height: 16),
        Text(
          '今日は',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 16,
                color: colors.secondaryLabel,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          dateLabel,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
        ),
        const SizedBox(height: 18),
        Divider(
          height: 1,
          thickness: 1,
          color: colors.separator.withValues(alpha: 0.75),
        ),
      ],
    );
  }
}

class _TodaySectionCard extends StatelessWidget {
  const _TodaySectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.15,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(TodayPage.cardRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: child,
        ),
      ],
    );
  }
}

class _TodayRoutineTaskRow extends StatelessWidget {
  const _TodayRoutineTaskRow({
    required this.task,
    required this.completed,
    this.onToggle,
    this.onTitleTap,
  });

  final Task task;
  final bool completed;
  final VoidCallback? onToggle;
  final VoidCallback? onTitleTap;

  @override
  Widget build(BuildContext context) {
    return _TodayInteractiveTaskRow(
      task: task,
      completed: completed,
      removing: false,
      onToggle: onToggle == null ? null : () async => onToggle!(),
      onTitleTap: onTitleTap,
    );
  }
}

class _TodayInteractiveTaskRow extends StatelessWidget {
  const _TodayInteractiveTaskRow({
    required this.task,
    required this.completed,
    required this.removing,
    this.onToggle,
    this.onTitleTap,
    this.prefix,
    this.trailing,
  });

  final Task task;
  final bool completed;
  final bool removing;
  final Future<void> Function()? onToggle;
  final VoidCallback? onTitleTap;
  final Widget? prefix;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;

    final row = SizedBox(
      height: 52,
      child: Row(
        children: [
          TaskCompletionToggle(
            completed: completed,
            onTap: onToggle == null ? _noop : () => unawaited(onToggle!()),
          ),
          const SizedBox(width: 12),
          if (prefix != null) ...[
            prefix!,
            const SizedBox(width: 10),
          ],
          Expanded(
            child: onTitleTap == null
                ? Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _titleStyle(context, colors, completed),
                  )
                : Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTitleTap,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _titleStyle(context, colors, completed),
                        ),
                      ),
                    ),
                  ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: removing ? const SizedBox.shrink() : row,
    );
  }

  TextStyle? _titleStyle(
    BuildContext context,
    FlowDoColors colors,
    bool completed,
  ) {
    return Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          decoration: completed ? TextDecoration.lineThrough : null,
          color: completed
              ? colors.secondaryLabel
              : Theme.of(context).colorScheme.onSurface,
        );
  }
}

class _TodayAchievementCard extends StatelessWidget {
  const _TodayAchievementCard({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '今日の達成率',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.15,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(TodayPage.cardRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 10,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: TodayPage.flowDoBlue.withValues(alpha: 0.12),
                      ),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress.clamp(0, 1),
                        child: const ColoredBox(color: TodayPage.flowDoBlue),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$percent%',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: TodayPage.flowDoBlue,
                      letterSpacing: -0.5,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

void _noop() {}
