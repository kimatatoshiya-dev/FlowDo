import 'package:flutter/material.dart';

import '../models/category_item.dart';
import '../theme/app_theme.dart';
import 'inbox_category_dropdown_trigger.dart';

/// Inbox「カテゴリー（全体）」— 横長セレクター + Bottom Sheet
class InboxDestinationSelector extends StatelessWidget {
  const InboxDestinationSelector({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onTap,
  });

  static const minTapHeight = 52.0;

  final List<CategoryItem> categories;
  final String? selectedCategoryId;
  final VoidCallback onTap;

  String get _label {
    if (selectedCategoryId == null) return '未選択';
    return resolveCategory(selectedCategoryId!, categories).name;
  }

  Color? get _selectedColor {
    if (selectedCategoryId == null) return null;
    return resolveCategory(selectedCategoryId!, categories).color;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final chipColor = _selectedColor;
    final isUnselected = selectedCategoryId == null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: InboxCategoryDropdownShell(
        key: const ValueKey('inbox_destination_selector'),
        onTap: onTap,
        minHeight: minTapHeight,
        padding: const EdgeInsets.fromLTRB(16, 0, 14, 0),
        child: Row(
          children: [
            if (isUnselected)
              Icon(
                Icons.check,
                size: 20,
                color: InboxCategoryDropdownStyle.flowDoBlue
                    .withValues(alpha: 0.88),
              )
            else
              CircleAvatar(radius: 5, backgroundColor: chipColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface.withValues(alpha: 0.9),
                    ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.expand_more_rounded,
              size: InboxCategoryDropdownStyle.iconSize,
              color: InboxCategoryDropdownStyle.flowDoBlue,
            ),
          ],
        ),
      ),
    );
  }
}
