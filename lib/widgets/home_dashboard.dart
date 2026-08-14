import 'package:flutter/material.dart';

import '../models/category_item.dart';
import '../models/flowdo_calendar.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';

/// カテゴリー別の未完了件数
class CategoryIncompleteCount {
  const CategoryIncompleteCount({
    required this.category,
    required this.count,
  });

  final CategoryItem category;
  final int count;
}

/// ホーム画面の統計ダッシュボード（PageView）
typedef CalendarDayTapCallback = void Function(DateTime day, DateTime today);

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({
    super.key,
    required this.tasks,
    required this.onCalendarDayTap,
    required this.onOpenTodayFocusSheet,
    required this.categoryCounts,
    this.onTodaySummaryTap,
    this.onWeekSummaryTap,
    this.onImportantSummaryTap,
    this.today,
  });

  final List<Task> tasks;
  final CalendarDayTapCallback onCalendarDayTap;
  final VoidCallback onOpenTodayFocusSheet;
  final List<CategoryIncompleteCount> categoryCounts;
  final VoidCallback? onTodaySummaryTap;
  final VoidCallback? onWeekSummaryTap;
  final VoidCallback? onImportantSummaryTap;
  final DateTime? today;

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late DateTime _displayedMonth;

  static const _calendarPageHeight = 452.0;

  @override
  void initState() {
    super.initState();
    final referenceToday = dateOnly(widget.today ?? DateTime.now());
    _displayedMonth = DateTime(referenceToday.year, referenceToday.month, 1);
  }

  @override
  void didUpdateWidget(covariant HomeDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.today != widget.today && widget.today != null) {
      final referenceToday = dateOnly(widget.today!);
      _displayedMonth = DateTime(referenceToday.year, referenceToday.month, 1);
    }
  }

  void _goToPreviousMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1);
    });
  }

  void _goToNextMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;
    final calendarData = buildFlowDoCalendarMonth(
      tasks: widget.tasks,
      month: _displayedMonth,
      today: widget.today,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          SizedBox(
            height: _calendarPageHeight,
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentPage = index),
              children: [
                _FlowDoCalendarPage(
                  calendarData: calendarData,
                  onDayTap: widget.onCalendarDayTap,
                  onOpenTodayFocusSheet: widget.onOpenTodayFocusSheet,
                  onPreviousMonth: _goToPreviousMonth,
                  onNextMonth: _goToNextMonth,
                  onTodaySummaryTap: widget.onTodaySummaryTap,
                  onWeekSummaryTap: widget.onWeekSummaryTap,
                  onImportantSummaryTap: widget.onImportantSummaryTap,
                ),
                _CategoryAnalysisPage(categoryCounts: widget.categoryCounts),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(2, (index) {
              final active = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: active ? 8 : 6,
                height: active ? 8 : 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? Theme.of(context).colorScheme.primary
                      : colors.secondaryLabel.withValues(alpha: 0.35),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _FlowDoCalendarPage extends StatelessWidget {
  const _FlowDoCalendarPage({
    required this.calendarData,
    required this.onDayTap,
    required this.onOpenTodayFocusSheet,
    required this.onPreviousMonth,
    required this.onNextMonth,
    this.onTodaySummaryTap,
    this.onWeekSummaryTap,
    this.onImportantSummaryTap,
  });

  final FlowDoCalendarMonthData calendarData;
  final CalendarDayTapCallback onDayTap;
  final VoidCallback onOpenTodayFocusSheet;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback? onTodaySummaryTap;
  final VoidCallback? onWeekSummaryTap;
  final VoidCallback? onImportantSummaryTap;

  static const _weekdayLabels = ['日', '月', '火', '水', '木', '金', '土'];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final monthTitle = formatCalendarMonthTitle(calendarData.month);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: colors.groupedSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CalendarSummaryRow(
            summary: calendarData.summary,
            onImportantTap: onImportantSummaryTap,
            onTodayTap: onTodaySummaryTap,
            onWeekTap: onWeekSummaryTap,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                key: const ValueKey('calendar_prev_month'),
                onPressed: onPreviousMonth,
                icon: const Text('◀', style: TextStyle(fontSize: 14, height: 1)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                visualDensity: VisualDensity.compact,
                tooltip: '前月',
              ),
              Expanded(
                child: Text(
                  monthTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.secondaryLabel,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              IconButton(
                key: const ValueKey('calendar_next_month'),
                onPressed: onNextMonth,
                icon: const Text('▶', style: TextStyle(fontSize: 14, height: 1)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                visualDensity: VisualDensity.compact,
                tooltip: '翌月',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (var index = 0; index < _weekdayLabels.length; index++)
                Expanded(
                  child: Center(
                    child: Text(
                      _weekdayLabels[index],
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: calendarWeekdayLabelColor(
                              weekdayIndex: index,
                              standardColor: colors.secondaryLabel,
                            ),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cellHeight = constraints.maxHeight / 6;

                return GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisExtent: cellHeight,
                  ),
                  itemCount: calendarData.firstWeekday + calendarData.daysInMonth,
                  itemBuilder: (context, index) {
                    if (index < calendarData.firstWeekday) {
                      return const SizedBox.shrink();
                    }

                    final dayNumber =
                        index - calendarData.firstWeekday + 1;
                    final day = DateTime(
                      calendarData.year,
                      calendarData.monthNumber,
                      dayNumber,
                    );
                    final isToday = isSameDay(day, calendarData.today);
                    final markers = calendarData.markersFor(day);

                    return _CalendarDayCell(
                      day: dayNumber,
                      date: day,
                      isToday: isToday,
                      markers: markers,
                      primaryColor: colorScheme.primary,
                      standardTextColor: Theme.of(context).colorScheme.onSurface,
                      onTap: () => onDayTap(day, calendarData.today),
                    );
                  },
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onOpenTodayFocusSheet,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                '▶ 重要タスク一覧',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarSummaryRow extends StatelessWidget {
  const _CalendarSummaryRow({
    required this.summary,
    this.onImportantTap,
    this.onTodayTap,
    this.onWeekTap,
  });

  final FlowDoCalendarSummary summary;
  final VoidCallback? onImportantTap;
  final VoidCallback? onTodayTap;
  final VoidCallback? onWeekTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;

    return Column(
      key: const ValueKey('dashboard_summary_row'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (summary.importantCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const ValueKey('dashboard_summary_important'),
                onTap: onImportantTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Text('📌', style: TextStyle(fontSize: 14, height: 1)),
                      const SizedBox(width: 4),
                      Text(
                        '${summary.importantCount}件',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: colors.secondaryLabel,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Row(
          children: [
            _FocusSummaryCard(
              key: const ValueKey('dashboard_summary_today'),
              emoji: '🔥',
              label: '今日',
              count: summary.dueTodayCount,
              onTap: onTodayTap,
            ),
            const SizedBox(width: 10),
            _FocusSummaryCard(
              key: const ValueKey('dashboard_summary_within7days'),
              emoji: '🗓️',
              label: '7日以内',
              count: summary.dueWithin7DaysCount,
              onTap: onWeekTap,
            ),
          ],
        ),
      ],
    );
  }
}

class _FocusSummaryCard extends StatelessWidget {
  const _FocusSummaryCard({
    super.key,
    required this.emoji,
    required this.label,
    required this.count,
    this.onTap,
  });

  final String emoji;
  final String label;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.completedTaskSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 16, height: 1.1),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.secondaryLabel,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$count',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1,
                      letterSpacing: -0.3,
                    ),
              ),
              const SizedBox(width: 2),
              Text(
                '件',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.secondaryLabel,
                      fontWeight: FontWeight.w500,
                      height: 1,
                    ),
              ),
            ],
          ),
        ],
      ),
    );

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: colorScheme.primary.withValues(alpha: 0.08),
          highlightColor: colorScheme.primary.withValues(alpha: 0.04),
          child: content,
        ),
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.day,
    required this.date,
    required this.isToday,
    required this.markers,
    required this.primaryColor,
    required this.standardTextColor,
    required this.onTap,
  });

  final int day;
  final DateTime date;
  final bool isToday;
  final FlowDoCalendarDayMarkers markers;
  final Color primaryColor;
  final Color standardTextColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: isToday
                  ? BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    )
                  : null,
              child: Text(
                '$day',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: calendarDayNumberColor(
                        day: date,
                        isToday: isToday,
                        standardColor: standardTextColor,
                      ),
                    ),
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 12,
              child: markers.hasAny
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (markers.showImportant)
                            const Text('📌', style: TextStyle(fontSize: 9, height: 1)),
                          if (markers.showDueToday)
                            const Text('🔥', style: TextStyle(fontSize: 9, height: 1)),
                          if (markers.showScheduled)
                            const Text('🗓️', style: TextStyle(fontSize: 9, height: 1)),
                        ],
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryAnalysisPage extends StatelessWidget {
  const _CategoryAnalysisPage({required this.categoryCounts});

  final List<CategoryIncompleteCount> categoryCounts;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: colors.groupedSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'カテゴリー別',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.secondaryLabel,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          if (categoryCounts.isEmpty)
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '未完了タスクはありません',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.secondaryLabel,
                      ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: categoryCounts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = categoryCounts[index];
                  return _StatRow(
                    emoji: categoryEmoji(item.category),
                    label: item.category.name,
                    count: item.count,
                    accent: item.category.color,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.emoji,
    required this.label,
    required this.count,
    required this.accent,
  });

  final String emoji;
  final String label;
  final int count;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;

    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18, height: 1)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.secondaryLabel,
                ),
          ),
        ),
        Text(
          '$count',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: accent,
              ),
        ),
        const SizedBox(width: 2),
        Text(
          '件',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.secondaryLabel,
              ),
        ),
      ],
    );
  }
}

/// カテゴリー名に合わせた表示用アイコン
String categoryEmoji(CategoryItem category) {
  return switch (category.id) {
    'work' => '📁',
    'personal' => '🏠',
    'shopping' => '🛒',
    _ => switch (category.name) {
        '仕事' => '📁',
        '家庭' || '私用' => '🏠',
        '買い物' => '🛒',
        _ => '📁',
      },
  };
}
