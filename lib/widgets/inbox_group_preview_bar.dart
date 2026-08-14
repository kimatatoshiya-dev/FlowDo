import 'package:flutter/material.dart';

import '../models/category_item.dart';
import 'category_bar.dart';
import 'category_name_dialog.dart';

/// Inbox 上部 — グループ一覧の表示専用横スクロール + グループ追加
class InboxGroupPreviewBar extends StatefulWidget {
  const InboxGroupPreviewBar({
    super.key,
    required this.categories,
    required this.onAdd,
    required this.onRename,
    required this.onDelete,
    required this.onReorder,
    this.addButtonKey = const ValueKey('inbox_category_add_chip'),
  });

  final List<CategoryItem> categories;
  final ValueChanged<String> onAdd;
  final ValueChanged<CategoryItem> onRename;
  final ValueChanged<CategoryItem> onDelete;
  final void Function(int oldIndex, int newIndex) onReorder;
  final Key addButtonKey;

  @override
  State<InboxGroupPreviewBar> createState() => _InboxGroupPreviewBarState();
}

class _InboxGroupPreviewBarState extends State<InboxGroupPreviewBar> {
  bool _isDialogOpen = false;
  final CategoryChipGestureTracker _chipGestures = CategoryChipGestureTracker();

  Future<void> _showAddDialog() async {
    if (_isDialogOpen) return;

    setState(() => _isDialogOpen = true);

    String? name;
    try {
      name = await promptAddCategoryName(context);
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
    if (_isDialogOpen || category.isSystem) return;

    await showCategoryActionsSheet(
      context,
      category: category,
      onRename: widget.onRename,
      onDelete: widget.onDelete,
    );
  }

  void _handleCategoryChipTap(CategoryItem category) {
    _chipGestures.handleTap(
      chipId: category.id,
      onSingleTap: () {},
      onDoubleTap: category.isSystem
          ? null
          : () => _showCategoryActions(category),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = CategoryItem.filterBarCategories(widget.categories);
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        kCategoryBarHorizontalInset,
        0,
        kCategoryBarHorizontalInset,
        0,
      ),
      child: SizedBox(
        height: kCategoryChipTapHeight,
        child: ScrollConfiguration(
          behavior: const CategoryBarScrollBehavior(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: HorizontalReorderableChipRow(
                  itemCount: items.length,
                  onReorder: widget.onReorder,
                  itemBuilder: (context, index) {
                    final category = items[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        right: index == items.length - 1
                            ? kCategoryChipSpacing
                            : kCategoryChipSpacing,
                      ),
                      child: CategoryGroupChip(
                        key: ValueKey('inbox_category_chip_${category.id}'),
                        label: category.name,
                        color: category.color,
                        visual: CategoryGroupChipVisual.preview,
                        onTap: () => _handleCategoryChipTap(category),
                      ),
                    );
                  },
                ),
              ),
              _InboxAddCategoryChip(
                key: widget.addButtonKey,
                enabled: !_isDialogOpen,
                onTap: _showAddDialog,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InboxAddCategoryChip extends StatelessWidget {
  const _InboxAddCategoryChip({
    super.key,
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(kCategoryChipTapHeight / 2),
        splashColor: colorScheme.primary.withValues(alpha: 0.08),
        highlightColor: colorScheme.primary.withValues(alpha: 0.04),
        child: SizedBox(
          height: kCategoryChipTapHeight,
          child: Center(
            child: Material(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
              shape: StadiumBorder(
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Icon(
                  Icons.add,
                  size: 18,
                  color: enabled
                      ? colorScheme.onSurface.withValues(alpha: 0.86)
                      : colorScheme.onSurface.withValues(alpha: 0.38),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
