import 'dart:math' as math;

import 'package:flutter/material.dart';

/// タスク登録直後のみ、カード全体に控えめなフィードバックを表示する
class RegistrationFeedbackWrapper extends StatefulWidget {
  const RegistrationFeedbackWrapper({
    super.key,
    required this.child,
    required this.enabled,
  });

  final Widget child;
  final bool enabled;

  @override
  State<RegistrationFeedbackWrapper> createState() =>
      _RegistrationFeedbackWrapperState();
}

class _RegistrationFeedbackWrapperState extends State<RegistrationFeedbackWrapper>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 500);
  static const _peakAlpha = 0.1;

  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _controller = AnimationController(vsync: this, duration: _duration)
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) return widget.child;

    final highlightColor = Theme.of(context).colorScheme.primary;

    return AnimatedBuilder(
      animation: _controller!,
      builder: (context, child) {
        final highlight = math.sin(_controller!.value * math.pi) * _peakAlpha;
        if (highlight <= 0.001) return child!;

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: highlightColor.withValues(alpha: highlight),
              ),
            ),
            child!,
          ],
        );
      },
      child: widget.child,
    );
  }
}
