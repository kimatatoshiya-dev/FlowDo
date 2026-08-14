import 'package:flutter/material.dart';

import '../models/category_item.dart';
import 'category_name_dialog.dart';

/// Apple HIG 準拠のグループチップ最小タップ高さ（pt）
const kCategoryChipTapHeight = 46.0;

/// チップ同士の間隔（従来 8px から +4px）
const kCategoryChipSpacing = 12.0;

/// 選択アニメーション時間（0.18〜0.22 秒）
const kCategoryChipSelectionDuration = Duration(milliseconds: 200);

/// 選択時の拡大率
const kCategoryChipSelectedScale = 1.03;

/// 横方向のコンテンツインセット（Apple 純正アプリ相当）
const kCategoryBarHorizontalInset = 20.0;

/// グループ D&D 中の iOS 風プレビュー
Widget categoryChipReorderProxyDecorator(
  Widget child,
  int index,
  Animation<double> animation,
) {
  return AnimatedBuilder(
    animation: animation,
    builder: (context, child) {
      final t = Curves.easeOutCubic.transform(animation.value);
      return Transform.scale(
        scale: 1 + (0.04 * t),
        child: Material(
          elevation: 6 * t,
          shadowColor: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(999),
          color: Colors.transparent,
          child: child,
        ),
      );
    },
    child: child,
  );
}

/// ホーム画面のカテゴリー一覧バー
class CategoryBar extends StatefulWidget {
  const CategoryBar({
    super.key,
    required this.categories,
    required this.selectedIds,
    required this.onSelected,
    required this.onAdd,
    required this.onRename,
    required this.onDelete,
    required this.onReorder,
    this.padding = const EdgeInsets.fromLTRB(
      kCategoryBarHorizontalInset,
      12,
      kCategoryBarHorizontalInset,
      0,
    ),
    this.addButtonKey = const ValueKey('category_add_chip'),
  });

  final List<CategoryItem> categories;
  final Set<String> selectedIds;
  final ValueChanged<String?> onSelected;
  final ValueChanged<String> onAdd;
  final ValueChanged<CategoryItem> onRename;
  final ValueChanged<CategoryItem> onDelete;
  final void Function(int oldIndex, int newIndex) onReorder;
  final EdgeInsetsGeometry padding;
  final Key addButtonKey;

  @override
  State<CategoryBar> createState() => _CategoryBarState();
}

class CategoryBarScrollBehavior extends ScrollBehavior {
  const CategoryBarScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  Widget buildOverscrollIndicator(
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

/// タップ／ダブルタップ判別（親 setState 後も状態を保持）
class CategoryChipGestureTracker {
  String? _lastChipId;
  DateTime? _lastTapAt;

  static const doubleTapWindow = Duration(milliseconds: 300);

  void handleTap({
    required String chipId,
    required VoidCallback onSingleTap,
    VoidCallback? onDoubleTap,
  }) {
    final now = DateTime.now();
    if (onDoubleTap != null &&
        _lastChipId == chipId &&
        _lastTapAt != null &&
        now.difference(_lastTapAt!) <= doubleTapWindow) {
      _lastChipId = null;
      _lastTapAt = null;
      onDoubleTap();
      return;
    }

    _lastChipId = chipId;
    _lastTapAt = now;
    onSingleTap();
  }
}

/// グループチップの見た目
enum CategoryGroupChipVisual { filter, preview }

/// 整理待ち・表示するグループで共通のグループチップ
class CategoryGroupChip extends StatelessWidget {
  const CategoryGroupChip({
    super.key,
    required this.label,
    required this.onTap,
    this.color,
    this.selected = false,
    this.visual = CategoryGroupChipVisual.filter,
  });

  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool selected;
  final CategoryGroupChipVisual visual;

  @override
  Widget build(BuildContext context) {
    final chip = switch (visual) {
      CategoryGroupChipVisual.filter => _AnimatedCategoryChipVisual(
          label: label,
          selected: selected,
          color: color,
        ),
      CategoryGroupChipVisual.preview => _PreviewCategoryChipVisual(
          label: label,
          color: color!,
        ),
    };

    return _ChipTapTarget(
      onTap: onTap,
      chip: chip,
    );
  }
}

class _PreviewCategoryChipVisual extends StatelessWidget {
  const _PreviewCategoryChipVisual({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

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
            CircleAvatar(
              radius: 5,
              backgroundColor: color,
            ),
            const SizedBox(width: 8),
            Text(
              label,
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

class _CategoryBarState extends State<CategoryBar> {
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
    if (category.isSystem || _isDialogOpen) return;

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
      onSingleTap: () => widget.onSelected(category.id),
      onDoubleTap: category.isSystem
          ? null
          : () => _showCategoryActions(category),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filterCategories = CategoryItem.filterBarCategories(widget.categories);

    return Padding(
      padding: widget.padding,
      child: SizedBox(
        height: kCategoryChipTapHeight,
        child: ScrollConfiguration(
          behavior: const CategoryBarScrollBehavior(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CategoryGroupChip(
                key: const ValueKey('category_chip_tap_all'),
                label: 'すべて',
                selected: widget.selectedIds.isEmpty,
                onTap: () => widget.onSelected(null),
              ),
              const SizedBox(width: kCategoryChipSpacing),
              Expanded(
                child: HorizontalReorderableChipRow(
                  itemCount: filterCategories.length,
                  onReorder: widget.onReorder,
                  itemBuilder: (context, index) {
                    final category = filterCategories[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        right: index == filterCategories.length - 1
                            ? 0
                            : kCategoryChipSpacing,
                      ),
                      child: CategoryGroupChip(
                        key: ValueKey('category_chip_tap_${category.id}'),
                        label: category.name,
                        color: category.color,
                        selected: widget.selectedIds.contains(category.id),
                        onTap: () => _handleCategoryChipTap(category),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: kCategoryChipSpacing),
              _AddCategoryChip(
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

/// 横スクロール + 長押しドラッグ並び替え（タップ／ダブルタップは子へ委譲）
class HorizontalReorderableChipRow extends StatelessWidget {
  const HorizontalReorderableChipRow({
    super.key,
    required this.itemCount,
    required this.onReorder,
    required this.itemBuilder,
  });

  final int itemCount;
  final void Function(int oldIndex, int newIndex) onReorder;
  final Widget Function(BuildContext context, int index) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < itemCount; index++)
            _HorizontalReorderableChipSlot(
              key: ValueKey('reorder_slot_$index'),
              index: index,
              onReorder: onReorder,
              child: itemBuilder(context, index),
            ),
        ],
      ),
    );
  }
}

class _HorizontalReorderableChipSlot extends StatelessWidget {
  const _HorizontalReorderableChipSlot({
    super.key,
    required this.index,
    required this.onReorder,
    required this.child,
  });

  final int index;
  final void Function(int oldIndex, int newIndex) onReorder;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<int>(
      data: index,
      hapticFeedbackOnStart: true,
      feedback: categoryChipDragFeedback(child),
      childWhenDragging: Opacity(
        opacity: 0.42,
        child: child,
      ),
      child: DragTarget<int>(
        onWillAcceptWithDetails: (details) => details.data != index,
        onAcceptWithDetails: (details) {
          final from = details.data;
          if (from == index) return;
          final insertIndex = from < index ? index + 1 : index;
          onReorder(from, insertIndex);
        },
        builder: (context, candidateData, rejectedData) => child,
      ),
    );
  }
}

Widget categoryChipDragFeedback(Widget child) {
  return Material(
    elevation: 6,
    shadowColor: Colors.black.withValues(alpha: 0.18),
    borderRadius: BorderRadius.circular(999),
    color: Colors.transparent,
    child: Transform.scale(
      scale: 1.04,
      child: child,
    ),
  );
}

/// Material → InkWell → SizedBox(46) → Center(Chip) で HitTest 領域を確保
class _ChipTapTarget extends StatelessWidget {
  const _ChipTapTarget({
    super.key,
    required this.onTap,
    required this.chip,
    this.enabled = true,
  });

  final VoidCallback? onTap;
  final Widget chip;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(kCategoryChipTapHeight / 2),
        splashColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        highlightColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.04),
        child: SizedBox(
          height: kCategoryChipTapHeight,
          child: Center(child: chip),
        ),
      ),
    );
  }
}

/// 選択状態をアニメーションするチップ見た目
class _AnimatedCategoryChipVisual extends StatelessWidget {
  const _AnimatedCategoryChipVisual({
    required this.label,
    required this.selected,
    this.color,
  });

  final String label;
  final bool selected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final chipColor = color ?? colorScheme.primary;
    final backgroundColor = selected
        ? chipColor.withValues(alpha: 0.19)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.72);
    final borderColor = selected
        ? chipColor.withValues(alpha: 0.58)
        : colorScheme.outlineVariant.withValues(alpha: 0.5);
    const animationCurve = Curves.easeOutCubic;
    final hasCategoryColor = color != null;

    return AnimatedScale(
      scale: selected ? kCategoryChipSelectedScale : 1,
      duration: kCategoryChipSelectionDuration,
      curve: animationCurve,
      alignment: Alignment.center,
      filterQuality: FilterQuality.medium,
      child: AnimatedContainer(
        duration: kCategoryChipSelectionDuration,
        curve: animationCurve,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor, width: selected ? 1.25 : 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasCategoryColor)
              _CategorySelectionMarker(
                color: chipColor,
                selected: selected,
              )
            else if (selected)
              _CategorySelectionMarker(
                color: chipColor,
                selected: true,
              ),
            if (hasCategoryColor || selected) const SizedBox(width: 8),
            AnimatedDefaultTextStyle(
              duration: kCategoryChipSelectionDuration,
              curve: animationCurve,
              style: Theme.of(context).textTheme.labelLarge!.copyWith(
                    color: selected
                        ? chipColor
                        : colorScheme.onSurface.withValues(alpha: 0.86),
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
                  ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

/// カテゴリー色ドット — 未選択はソフトな丸、選択中は solid ●
class _CategorySelectionMarker extends StatelessWidget {
  const _CategorySelectionMarker({
    required this.color,
    required this.selected,
  });

  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 14,
      child: Center(
        child: AnimatedSwitcher(
          duration: kCategoryChipSelectionDuration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: selected
              ? _SolidSelectionDot(
                  key: const ValueKey('category_marker_selected'),
                  color: color,
                )
              : _SoftCategoryDot(
                  key: const ValueKey('category_marker_unselected'),
                  color: color,
                ),
        ),
      ),
    );
  }
}

/// 未選択: カテゴリー色のソフトな丸（🔵）
class _SoftCategoryDot extends StatelessWidget {
  const _SoftCategoryDot({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.32),
        border: Border.all(
          color: color.withValues(alpha: 0.78),
          width: 1.5,
        ),
      ),
    );
  }
}

/// 選択中: カテゴリー色の solid ●（表示中インジケーター）
class _SolidSelectionDot extends StatelessWidget {
  const _SolidSelectionDot({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _AddCategoryChip extends StatelessWidget {
  const _AddCategoryChip({
    super.key,
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _ChipTapTarget(
      enabled: enabled,
      onTap: onTap,
      chip: Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        shape: StadiumBorder(
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Icon(
            Icons.add,
            size: 18,
            color: enabled
                ? colorScheme.onSurface.withValues(alpha: 0.86)
                : colorScheme.onSurface.withValues(alpha: 0.38),
          ),
        ),
      ),
    );
  }
}

/// カテゴリー長押しメニュー（整理待ち・表示するグループで共通）
Future<void> showCategoryActionsSheet(
  BuildContext context, {
  required CategoryItem category,
  required ValueChanged<CategoryItem> onRename,
  required ValueChanged<CategoryItem> onDelete,
}) {
  if (category.isSystem) return Future<void>.value();

  return showModalBottomSheet<void>(
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
              runCategoryActionAfterSheetClosed(() => onRename(category));
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
              runCategoryActionAfterSheetClosed(() => onDelete(category));
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> runCategoryActionAfterSheetClosed(VoidCallback action) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await runAfterDialogClosed(() async {});
  action();
}

/// カテゴリー追加ダイアログ（整理待ち・表示するグループで共通）
Future<String?> promptAddCategoryName(BuildContext context) {
  return showCategoryNameDialog(
    context,
    title: 'カテゴリー追加',
    confirmLabel: '追加',
  );
}
