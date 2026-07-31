import 'package:flutter/material.dart';

import '../models/category_item.dart';
import 'category_name_dialog.dart';

/// ホーム画面のカテゴリー一覧バー
class CategoryBar extends StatefulWidget {
  const CategoryBar({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    required this.onAdd,
    required this.onRename,
    required this.onDelete,
  });

  final List<CategoryItem> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelected;
  final ValueChanged<String> onAdd;
  final ValueChanged<CategoryItem> onRename;
  final ValueChanged<CategoryItem> onDelete;

  @override
  State<CategoryBar> createState() => _CategoryBarState();
}

class _CategoryBarState extends State<CategoryBar> {
  bool _isDialogOpen = false;

  Future<void> _showAddDialog() async {
    if (_isDialogOpen) return;

    setState(() => _isDialogOpen = true);

    String? name;
    try {
      name = await showCategoryNameDialog(
        context,
        title: 'カテゴリー追加',
        confirmLabel: '追加',
      );
    } finally {
      if (mounted) {
        setState(() => _isDialogOpen = false);
      }
    }

    if (name == null || name.isEmpty || !mounted) return;

    FocusManager.instance.primaryFocus?.unfocus();
    await runAfterDialogClosed(() async {});

    if (mounted) {
      widget.onAdd(name);
    }
  }

  Future<void> _showCategoryActions(CategoryItem category) async {
    if (category.isSystem || _isDialogOpen) return;

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('名前変更'),
              onTap: () {
                Navigator.pop(context);
                _runAfterSheetClosed(() => widget.onRename(category));
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                '削除',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _runAfterSheetClosed(() => widget.onDelete(category));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runAfterSheetClosed(VoidCallback action) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await runAfterDialogClosed(() async {});
    if (mounted) action();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _CategoryChip(
              label: 'すべて',
              selected: widget.selectedId == null,
              onTap: () => widget.onSelected(null),
            ),
            const SizedBox(width: 8),
            for (final category in CategoryItem.filterBarCategories(
              widget.categories,
            ))
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _CategoryChip(
                  label: category.name,
                  color: category.color,
                  selected: widget.selectedId == category.id,
                  onTap: () {
                    widget.onSelected(
                      widget.selectedId == category.id ? null : category.id,
                    );
                  },
                  onLongPress: category.isSystem
                      ? null
                      : () => _showCategoryActions(category),
                ),
              ),
            _AddCategoryChip(
              enabled: !_isDialogOpen,
              onTap: _showAddDialog,
            ),
          ],
        ),
      ),
    );
  }
}

/// Overlay を使わないカテゴリーチップ
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
    this.onLongPress,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final chipColor = color ?? colorScheme.primary;
    final backgroundColor = selected
        ? chipColor.withValues(alpha: 0.15)
        : colorScheme.surfaceContainerHighest;
    final borderColor = selected ? chipColor : colorScheme.outlineVariant;

    return Material(
      color: backgroundColor,
      shape: StadiumBorder(side: BorderSide(color: borderColor)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (color != null) ...[
                CircleAvatar(radius: 6, backgroundColor: chipColor),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected ? chipColor : colorScheme.onSurface,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddCategoryChip extends StatelessWidget {
  const _AddCategoryChip({
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      key: const ValueKey('category_add_chip'),
      color: colorScheme.surfaceContainerHighest,
      shape: StadiumBorder(
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Icon(
            Icons.add,
            size: 18,
            color: enabled
                ? colorScheme.onSurface
                : colorScheme.onSurface.withValues(alpha: 0.38),
          ),
        ),
      ),
    );
  }
}
