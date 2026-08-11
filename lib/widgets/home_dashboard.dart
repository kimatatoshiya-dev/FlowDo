import 'package:flutter/material.dart';

import '../models/category_item.dart';
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
    required this.pinnedCount,
    required this.dueTodayCount,
    required this.dueWithin7DaysCount,
    required this.categoryCounts,
  });

  final int pinnedCount;
  final int dueTodayCount;
  final int dueWithin7DaysCount;
  final List<CategoryIncompleteCount> categoryCounts;

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

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
            height: 168,
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentPage = index),
              children: [
                _TodayFocusPage(
                  pinnedCount: widget.pinnedCount,
                  dueTodayCount: widget.dueTodayCount,
                  dueWithin7DaysCount: widget.dueWithin7DaysCount,
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
  });

  final int pinnedCount;
  final int dueTodayCount;
  final int dueWithin7DaysCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

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
            '今日やること',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.secondaryLabel,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          _StatRow(
            emoji: '📌',
            label: '固定',
            count: pinnedCount,
            accent: const Color(0xFFFF9500),
          ),
          const SizedBox(height: 8),
          _StatRow(
            emoji: '🔥',
            label: '今日期限',
            count: dueTodayCount,
            accent: const Color(0xFFFF3B30),
          ),
          const SizedBox(height: 8),
          _StatRow(
            emoji: '📅',
            label: '7日以内',
            count: dueWithin7DaysCount,
            accent: colorScheme.primary,
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
                separatorBuilder: (_, __) => const SizedBox(height: 8),
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
