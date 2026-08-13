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
    this.addButtonKey = const ValueKey('inbox_category_add_chip'),
  });

  final List<CategoryItem> categories;
  final ValueChanged<String> onAdd;
  final Key addButtonKey;

  @override
  State<InboxGroupPreviewBar> createState() => _InboxGroupPreviewBarState();
}

class _InboxGroupPreviewBarState extends State<InboxGroupPreviewBar> {
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
          behavior: const _CategoryBarScrollBehavior(),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.only(right: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: kCategoryChipSpacing),
                  _GroupPreviewChip(category: items[i]),
                ],
                const SizedBox(width: kCategoryChipSpacing),
                _InboxAddCategoryChip(
                  key: widget.addButtonKey,
                  enabled: !_isDialogOpen,
                  onTap: _showAddDialog,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupPreviewChip extends StatelessWidget {
  const _GroupPreviewChip({required this.category});

  final CategoryItem category;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
      shape: StadiumBorder(
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 5, backgroundColor: category.color),
            const SizedBox(width: 8),
            Text(
              category.name,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface.withValues(alpha: 0.88),
                  ),
            ),
          ],
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

/// [CategoryBar] と同じスクロール挙動
class _CategoryBarScrollBehavior extends ScrollBehavior {
  const _CategoryBarScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        );
      default:
        return const AlwaysScrollableScrollPhysics();
    }
  }
}
