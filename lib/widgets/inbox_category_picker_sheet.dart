import 'package:flutter/material.dart';

import '../models/category_item.dart';
import '../theme/app_theme.dart';

/// Inbox タスクのグループ（カテゴリー）を選ぶシート
enum _UnselectedIndicator { check, circle }

class InboxCategoryPickerSheet extends StatelessWidget {
  const InboxCategoryPickerSheet({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    this.includeUnselectedOption = false,
    this.unselectedIndicator = _UnselectedIndicator.check,
    this.unselectedReturnsUncategorized = false,
    this.title = 'グループを選択',
    this.subtitle = '整理するまでInboxに残ります',
  });

  final List<CategoryItem> categories;
  final String? selectedCategoryId;
  final bool includeUnselectedOption;
  final _UnselectedIndicator unselectedIndicator;
  final bool unselectedReturnsUncategorized;
  final String title;
  final String subtitle;

  static Future<String?> show(
    BuildContext context, {
    required List<CategoryItem> categories,
    required String selectedCategoryId,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => InboxCategoryPickerSheet(
        categories: categories,
        selectedCategoryId: selectedCategoryId,
      ),
    );
  }

  /// 整理先セレクター用 — `null` を返すと「未選択」
  static Future<String?> showForDestination(
    BuildContext context, {
    required List<CategoryItem> categories,
    String? selectedCategoryId,
  }) {
    return showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (context) => InboxCategoryPickerSheet(
        categories: categories,
        selectedCategoryId: selectedCategoryId,
        includeUnselectedOption: true,
        unselectedIndicator: _UnselectedIndicator.check,
        title: 'カテゴリー（全体）を選択',
        subtitle: '新しく追加するタスクの初期グループ',
      ),
    );
  }

  /// 個別タスク用 — 未選択は [CategoryItem.uncategorizedId]
  static Future<String?> showForTask(
    BuildContext context, {
    required List<CategoryItem> categories,
    required String selectedCategoryId,
  }) {
    return showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (context) => InboxCategoryPickerSheet(
        categories: categories,
        selectedCategoryId: selectedCategoryId,
        includeUnselectedOption: true,
        unselectedIndicator: _UnselectedIndicator.circle,
        title: 'カテゴリーを選択',
        subtitle: 'このタスクのグループ',
        unselectedReturnsUncategorized: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;
    final filterCategories = CategoryItem.filterBarCategories(categories);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.secondaryLabel,
                  ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.45,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (includeUnselectedOption)
                      _UnselectedOptionTile(
                        selected: unselectedReturnsUncategorized
                            ? selectedCategoryId ==
                                CategoryItem.uncategorizedId
                            : selectedCategoryId == null,
                        indicator: unselectedIndicator,
                        onTap: () => Navigator.pop(
                          context,
                          unselectedReturnsUncategorized
                              ? CategoryItem.uncategorizedId
                              : null,
                        ),
                      ),
                    for (final category in includeUnselectedOption
                        ? filterCategories
                        : categories)
                      _CategoryOptionTile(
                        category: category,
                        selected: category.id == selectedCategoryId,
                        onTap: () => Navigator.pop(context, category.id),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnselectedOptionTile extends StatelessWidget {
  const _UnselectedOptionTile({
    required this.selected,
    required this.onTap,
    this.indicator = _UnselectedIndicator.check,
  });

  final bool selected;
  final VoidCallback onTap;
  final _UnselectedIndicator indicator;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final Widget leading;
    switch (indicator) {
      case _UnselectedIndicator.circle:
        leading = Icon(
          selected ? Icons.circle : Icons.circle_outlined,
          size: selected ? 12 : 14,
          color: selected
              ? colorScheme.primary
              : colorScheme.onSurface.withValues(alpha: 0.45),
        );
      case _UnselectedIndicator.check:
        leading = Icon(
          Icons.check,
          size: 18,
          color: selected
              ? colorScheme.primary
              : colorScheme.onSurface.withValues(alpha: 0.28),
        );
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: leading,
      title: Text(
        '未選択',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
      ),
      onTap: onTap,
    );
  }
}

class _CategoryOptionTile extends StatelessWidget {
  const _CategoryOptionTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final CategoryItem category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 6,
        backgroundColor: category.color,
      ),
      title: Text(
        category.name,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
      ),
      trailing: selected
          ? Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: category.color,
              ),
            )
          : null,
      onTap: onTap,
    );
  }
}
