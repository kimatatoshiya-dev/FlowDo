import 'package:flutter/material.dart';

import '../models/category_item.dart';
import '../theme/app_theme.dart';

/// Inbox タスクのグループ（カテゴリー）を選ぶシート
class InboxCategoryPickerSheet extends StatelessWidget {
  const InboxCategoryPickerSheet({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
  });

  final List<CategoryItem> categories;
  final String selectedCategoryId;

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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'グループを選択',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '整理するまでInboxに残ります',
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
                    for (final category in categories)
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
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 6,
        backgroundColor: category.color,
      ),
      title: Text(category.name),
      trailing: selected
          ? Icon(Icons.check, color: colorScheme.primary, size: 20)
          : null,
      onTap: onTap,
    );
  }
}
