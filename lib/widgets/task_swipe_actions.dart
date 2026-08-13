import 'package:flutter/material.dart';

const _swipeCompleteColor = Color(0xFF34C759);
const _swipeEditColor = Color(0xFF007AFF);
const _swipeDeleteColor = Color(0xFFFF3B30);

/// タスク行のスワイプ操作（完了 / 編集 / 削除）
class TaskSwipeActions extends StatefulWidget {
  const TaskSwipeActions({
    super.key,
    required this.child,
    required this.onComplete,
    required this.onEdit,
    required this.onDismissDelete,
    required this.confirmDelete,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onComplete;
  final VoidCallback onEdit;
  final VoidCallback onDismissDelete;
  final Future<bool> Function() confirmDelete;
  final bool enabled;

  @override
  State<TaskSwipeActions> createState() => TaskSwipeActionsState();
}

class TaskSwipeActionsState extends State<TaskSwipeActions>
    with SingleTickerProviderStateMixin {
  late final AnimationController _snapController;
  Animation<double>? _snapAnimation;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..addListener(() {
        if (_snapAnimation != null) {
          setState(() => _dragOffset = _snapAnimation!.value);
        }
      });
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  double _completeThreshold(double width) => width * 0.28;

  double _editThreshold(double width) => -width * 0.28;

  double _deleteThreshold(double width) => -width * 0.52;

  double _maxDrag(double width) => width * 0.62;

  void _onHorizontalDragUpdate(DragUpdateDetails details, double width) {
    if (!widget.enabled) return;
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx).clamp(
        -_maxDrag(width),
        _maxDrag(width) * 0.55,
      );
    });
  }

  Future<void> _snapTo(double target) async {
    _snapAnimation = Tween<double>(begin: _dragOffset, end: target).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic),
    );
    await _snapController.forward(from: 0);
    if (!mounted) return;
    setState(() => _dragOffset = target);
  }

  Future<void> _onHorizontalDragEnd(double width) async {
    if (!widget.enabled) return;

    if (_dragOffset >= _completeThreshold(width)) {
      widget.onComplete();
      await _snapTo(0);
      return;
    }

    if (_dragOffset <= _deleteThreshold(width)) {
      final confirmed = await widget.confirmDelete();
      if (!mounted) return;
      if (confirmed) {
        widget.onDismissDelete();
        return;
      }
      await _snapTo(0);
      return;
    }

    if (_dragOffset <= _editThreshold(width)) {
      widget.onEdit();
      await _snapTo(0);
      return;
    }

    await _snapTo(0);
  }

  @visibleForTesting
  void debugSetDragOffset(double offset) {
    setState(() => _dragOffset = offset);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final completeThreshold = _completeThreshold(width);
        final editThreshold = _editThreshold(width);
        final deleteThreshold = _deleteThreshold(width);

        final completeProgress =
            (_dragOffset / completeThreshold).clamp(0.0, 1.0);
        final editProgress = _dragOffset >= 0
            ? 0.0
            : ((- _dragOffset) / (-editThreshold)).clamp(0.0, 1.0);
        final deleteProgress = _dragOffset >= editThreshold
            ? 0.0
            : ((_dragOffset - editThreshold) /
                    (deleteThreshold - editThreshold))
                .clamp(0.0, 1.0);

        return ClipRect(
          child: Stack(
            children: [
              Positioned.fill(
                child: _SwipeActionBackground(
                  dragOffset: _dragOffset,
                  completeProgress: completeProgress,
                  editProgress: editProgress,
                  deleteProgress: deleteProgress,
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: widget.enabled
                    ? (details) => _onHorizontalDragUpdate(details, width)
                    : null,
                onHorizontalDragEnd: widget.enabled
                    ? (_) => _onHorizontalDragEnd(width)
                    : null,
                child: Transform.translate(
                  offset: Offset(_dragOffset, 0),
                  child: widget.child,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SwipeActionBackground extends StatelessWidget {
  const _SwipeActionBackground({
    required this.dragOffset,
    required this.completeProgress,
    required this.editProgress,
    required this.deleteProgress,
  });

  final double dragOffset;
  final double completeProgress;
  final double editProgress;
  final double deleteProgress;

  @override
  Widget build(BuildContext context) {
    if (dragOffset > 0) {
      return _SwipeActionPanel(
        alignment: Alignment.centerLeft,
        color: _swipeCompleteColor,
        icon: '✓',
        progress: completeProgress,
        padding: const EdgeInsets.only(left: 22),
      );
    }

    if (deleteProgress > 0.08) {
      return _SwipeActionPanel(
        alignment: Alignment.centerRight,
        color: _swipeDeleteColor,
        icon: '🗑',
        progress: deleteProgress,
        padding: const EdgeInsets.only(right: 22),
      );
    }

    if (editProgress > 0.08) {
      return _SwipeActionPanel(
        alignment: Alignment.centerRight,
        color: _swipeEditColor,
        icon: '✏️',
        progress: editProgress,
        padding: const EdgeInsets.only(right: 22),
      );
    }

    return const SizedBox.shrink();
  }
}

class _SwipeActionPanel extends StatelessWidget {
  const _SwipeActionPanel({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.progress,
    required this.padding,
  });

  final Alignment alignment;
  final Color color;
  final String icon;
  final double progress;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: padding,
      color: color.withValues(alpha: 0.12 + (0.18 * progress)),
      child: Opacity(
        opacity: 0.35 + (0.65 * progress),
        child: Transform.scale(
          scale: 0.82 + (0.18 * progress),
          child: Text(
            icon,
            style: TextStyle(
              fontSize: 22,
              height: 1,
              shadows: [
                Shadow(
                  color: color.withValues(alpha: 0.25),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
