import 'package:flutter/material.dart';

/// FlowDo ブランド — カテゴリープルダウン共通スタイル
class InboxCategoryDropdownStyle {
  InboxCategoryDropdownStyle._();

  static const flowDoBlue = Color(0xFF007AFF);
  static const pressDuration = Duration(milliseconds: 150);
  static const shellBorderRadius = 17.0;
  static const triggerBorderRadius = 16.0;
  static const borderWidth = 1.1;
  static const borderOpacity = 0.45;
  static const backgroundTint = 0.065;
  static const pressedTint = 0.105;
  static const iconSize = 19.0;
  static const minTapSize = 44.0;

  static Color surfaceBase(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.surface
        : Colors.white;
  }

  static Color background(BuildContext context, {bool pressed = false}) {
    return Color.lerp(
      surfaceBase(context),
      flowDoBlue,
      pressed ? pressedTint : backgroundTint,
    )!;
  }

  static Color get borderColor =>
      flowDoBlue.withValues(alpha: borderOpacity);
}

/// 押下アニメーション付きブランドシェル（行全体 / コンパクト共通）
class InboxCategoryDropdownShell extends StatefulWidget {
  const InboxCategoryDropdownShell({
    super.key,
    required this.onTap,
    required this.child,
    this.borderRadius = InboxCategoryDropdownStyle.shellBorderRadius,
    this.minWidth,
    this.minHeight = InboxCategoryDropdownStyle.minTapSize,
    this.padding = EdgeInsets.zero,
  });

  final VoidCallback onTap;
  final Widget child;
  final double borderRadius;
  final double? minWidth;
  final double minHeight;
  final EdgeInsetsGeometry padding;

  @override
  State<InboxCategoryDropdownShell> createState() =>
      _InboxCategoryDropdownShellState();
}

class _InboxCategoryDropdownShellState extends State<InboxCategoryDropdownShell> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) {
        _setPressed(false);
        widget.onTap();
      },
      onTapCancel: () => _setPressed(false),
      child: AnimatedContainer(
        duration: InboxCategoryDropdownStyle.pressDuration,
        curve: Curves.easeOut,
        constraints: BoxConstraints(
          minWidth: widget.minWidth ?? 0,
          minHeight: widget.minHeight,
        ),
        padding: widget.padding,
        decoration: BoxDecoration(
          color: InboxCategoryDropdownStyle.background(
            context,
            pressed: _pressed,
          ),
          borderRadius: radius,
          border: Border.all(
            color: InboxCategoryDropdownStyle.borderColor,
            width: InboxCategoryDropdownStyle.borderWidth,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

/// Inbox カテゴリー選択 — 視認性の高いプルダウントリガー（44pt+）
class InboxCategoryDropdownTrigger extends StatelessWidget {
  const InboxCategoryDropdownTrigger({
    super.key,
    required this.onTap,
    this.tooltip,
  });

  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final trigger = InboxCategoryDropdownShell(
      onTap: onTap,
      borderRadius: InboxCategoryDropdownStyle.triggerBorderRadius,
      minWidth: InboxCategoryDropdownStyle.minTapSize,
      minHeight: InboxCategoryDropdownStyle.minTapSize,
      child: Center(
        child: Icon(
          Icons.expand_more_rounded,
          size: InboxCategoryDropdownStyle.iconSize,
          color: InboxCategoryDropdownStyle.flowDoBlue,
        ),
      ),
    );

    if (tooltip == null) return trigger;

    return Tooltip(message: tooltip!, child: trigger);
  }
}
