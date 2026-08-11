import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Inbox 整理（リストへ移動）待機中の確認アニメーション
class InboxPromotePendingWrapper extends StatefulWidget {
  const InboxPromotePendingWrapper({
    super.key,
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  State<InboxPromotePendingWrapper> createState() =>
      _InboxPromotePendingWrapperState();
}

class _InboxPromotePendingWrapperState extends State<InboxPromotePendingWrapper>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _startController();
    }
  }

  @override
  void didUpdateWidget(covariant InboxPromotePendingWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) {
      _startController();
    } else if (!widget.enabled && oldWidget.enabled) {
      _controller?.dispose();
      _controller = null;
    }
  }

  void _startController() {
    _controller?.dispose();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || _controller == null) return widget.child;

    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _controller!,
      builder: (context, child) {
        final pulse = 0.5 + (math.sin(_controller!.value * math.pi * 2) * 0.5);
        final borderAlpha = 0.22 + (pulse * 0.28);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: borderAlpha),
                  width: 1.5,
                ),
                color: colorScheme.primary.withValues(alpha: 0.05 + pulse * 0.04),
              ),
              child: child,
            ),
            Positioned(
              top: 6,
              right: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'リストへ移動中…',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: widget.child,
    );
  }
}
