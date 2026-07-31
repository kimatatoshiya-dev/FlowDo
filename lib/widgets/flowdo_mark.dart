import 'package:flutter/material.dart';

import '../theme/flowdo_brand.dart';

/// FlowDo アイコン風の3ドットマーク
class FlowDoMark extends StatelessWidget {
  const FlowDoMark({
    super.key,
    this.size = 20,
    this.intensity = 1,
  });

  final double size;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final colors = flowdoBrandColors;
    final alpha = (0.42 + intensity * 0.22).clamp(0.38, 0.72);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _FlowDoMarkPainter(
          colors: colors,
          alpha: alpha,
        ),
      ),
    );
  }
}

class _FlowDoMarkPainter extends CustomPainter {
  _FlowDoMarkPainter({
    required this.colors,
    required this.alpha,
  });

  final List<Color> colors;
  final double alpha;

  @override
  void paint(Canvas canvas, Size size) {
    if (colors.length < 3) return;

    final scale = size.width / 20;

    _dot(canvas, Offset(5 * scale, 11 * scale), colors[0], 3.2 * scale);
    _dot(canvas, Offset(10 * scale, 6 * scale), colors[1], 2.6 * scale);
    _dot(canvas, Offset(14 * scale, 13 * scale), colors[2], 2.2 * scale);
  }

  void _dot(Canvas canvas, Offset center, Color color, double radius) {
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = color.withValues(alpha: alpha),
    );
  }

  @override
  bool shouldRepaint(covariant _FlowDoMarkPainter oldDelegate) {
    return oldDelegate.alpha != alpha;
  }
}
