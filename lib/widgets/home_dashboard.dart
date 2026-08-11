import 'package:flutter/material.dart';

import '../models/category_item.dart';
import '../models/flowdo_calendar.dart';
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
class HomeDashboard extends StatefulWidget {
  const HomeDashboard({
    super.key,
    required this.calendarData,
    required this.onCalendarDayTap,
    required this.categoryCounts,
  });

  final FlowDoCalendarMonthData calendarData;
  final ValueChanged<DateTime> onCalendarDayTap;
  final List<CategoryIncompleteCount> categoryCounts;

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _calendarPageHeight = 332.0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;

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
                  calendarData: widget.calendarData,
                  onDayTap: widget.onCalendarDayTap,
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
  });

  final FlowDoCalendarMonthData calendarData;
  final ValueChanged<DateTime> onDayTap;

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
          _CalendarSummaryRow(summary: calendarData.summary),
          const SizedBox(height: 12),
          Text(
            monthTitle,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.secondaryLabel,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final label in _weekdayLabels)
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colors.secondaryLabel,
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
                      isToday: isToday,
                      markers: markers,
                      primaryColor: colorScheme.primary,
                      onTap: () => onDayTap(day),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarSummaryRow extends StatelessWidget {
  const _CalendarSummaryRow({required this.summary});

  final FlowDoCalendarSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SummaryBadge(emoji: '📌', count: summary.importantCount),
        const SizedBox(width: 16),
        _SummaryBadge(emoji: '🔥', count: summary.dueTodayCount),
        const SizedBox(width: 16),
        _SummaryBadge(emoji: '📅', count: summary.dueThisMonthCount),
      ],
    );
  }
}

class _SummaryBadge extends StatelessWidget {
  const _SummaryBadge({
    required this.emoji,
    required this.count,
  });

  final String emoji;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 15, height: 1)),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.day,
    required this.isToday,
    required this.markers,
    required this.primaryColor,
    required this.onTap,
  });

  final int day;
  final bool isToday;
  final FlowDoCalendarDayMarkers markers;
  final Color primaryColor;
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
                      color: isToday ? Colors.white : null,
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
                            const Text('📅', style: TextStyle(fontSize: 9, height: 1)),
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
