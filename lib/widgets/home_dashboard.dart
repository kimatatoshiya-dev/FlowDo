import 'package:flutter/material.dart';

import '../models/category_item.dart';
import '../models/today_focus.dart';
import '../theme/app_theme.dart';
import 'flowdo_icons.dart';

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
    required this.pinnedCount,
    required this.dueTodayCount,
    required this.dueWithin7DaysCount,
    required this.categoryCounts,
    required this.onOpenTodayFocusSheet,
  });

  final int pinnedCount;
  final int dueTodayCount;
  final int dueWithin7DaysCount;
  final List<CategoryIncompleteCount> categoryCounts;
  final VoidCallback onOpenTodayFocusSheet;

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _todayFocusPageHeight = 212.0;

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
            height: _todayFocusPageHeight,
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentPage = index),
              children: [
                _TodayFocusPage(
                  pinnedCount: widget.pinnedCount,
                  dueTodayCount: widget.dueTodayCount,
                  dueWithin7DaysCount: widget.dueWithin7DaysCount,
                  onOpenTodayFocusSheet: widget.onOpenTodayFocusSheet,
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

class _TodayFocusPage extends StatelessWidget {
  const _TodayFocusPage({
    required this.pinnedCount,
    required this.dueTodayCount,
    required this.dueWithin7DaysCount,
    required this.onOpenTodayFocusSheet,
  });

  final int pinnedCount;
  final int dueTodayCount;
  final int dueWithin7DaysCount;
  final VoidCallback onOpenTodayFocusSheet;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: colors.secondaryLabel,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      decoration: BoxDecoration(
        color: colors.groupedSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '今日やること',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.secondaryLabel,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 14),
          _TodayFocusStatRow(
            kind: TodayFocusFilterKind.important,
            label: '重要',
            count: pinnedCount,
            accent: const Color(0xFFFF9500),
            labelStyle: labelStyle,
          ),
          const SizedBox(height: 10),
          _TodayFocusStatRow(
            kind: TodayFocusFilterKind.dueToday,
            label: '今日期限',
            count: dueTodayCount,
            accent: const Color(0xFFFF3B30),
            labelStyle: labelStyle,
          ),
          const SizedBox(height: 10),
          _TodayFocusStatRow(
            kind: TodayFocusFilterKind.dueWithin7Days,
            label: '7日以内',
            count: dueWithin7DaysCount,
            accent: colorScheme.primary,
            labelStyle: labelStyle,
            iconColor: colorScheme.primary,
          ),
          const Spacer(),
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

class _TodayFocusStatRow extends StatelessWidget {
  const _TodayFocusStatRow({
    required this.kind,
    required this.label,
    required this.count,
    required this.accent,
    required this.labelStyle,
    this.iconColor,
  });

  final TodayFocusFilterKind kind;
  final String label;
  final int count;
  final Color accent;
  final TextStyle? labelStyle;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;

    return Row(
      children: [
        TodayFocusLeadingIcon(
          kind: kind,
          size: 18,
          color: iconColor ?? colors.secondaryLabel,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: labelStyle),
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
