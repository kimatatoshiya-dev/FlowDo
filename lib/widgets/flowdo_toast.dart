import 'dart:async';

import 'package:flutter/material.dart';

/// iOS 純正 Toast 風の軽量フィードバック（Snackbar より控えめ）
class FlowDoToast {
  FlowDoToast._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static const displayDuration = Duration(milliseconds: 800);

  static void show(BuildContext context, String message) {
    hide();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _FlowDoToastOverlay(
        message: message,
        bottomPadding: MediaQuery.paddingOf(context).bottom + 20,
      ),
    );

    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(displayDuration, hide);
  }

  static void hide() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

class _FlowDoToastOverlay extends StatefulWidget {
  const _FlowDoToastOverlay({
    required this.message,
    required this.bottomPadding,
  });

  final String message;
  final double bottomPadding;

  @override
  State<_FlowDoToastOverlay> createState() => _FlowDoToastOverlayState();
}

class _FlowDoToastOverlayState extends State<_FlowDoToastOverlay>
    with SingleTickerProviderStateMixin {
  static const _fadeDuration = Duration(milliseconds: 180);

  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _fadeDuration,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    unawaited(_controller.forward());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: widget.bottomPadding),
              child: FadeTransition(
                opacity: _opacity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3A3C).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 11,
                    ),
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
