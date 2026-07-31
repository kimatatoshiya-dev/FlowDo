import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// ホーム画面の統計ダッシュボード
class HomeDashboard extends StatelessWidget {
  const HomeDashboard({
    super.key,
    required this.completedCount,
    required this.pendingCount,
    required this.dueTodayCount,
    required this.totalCount,
  });

  final int completedCount;
  final int pendingCount;
  final int dueTodayCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final rate = totalCount == 0 ? 0.0 : completedCount / totalCount;
    final percent = (rate * 100).round();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.groupedSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: CustomPaint(
              painter: _DonutChartPainter(
                progress: rate,
                trackColor: colorScheme.primary.withValues(alpha: 0.12),
                progressColor: colorScheme.primary,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$percent%',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      '完了率',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colors.secondaryLabel,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              children: [
                _StatRow(
                  label: '未完了',
                  count: pendingCount,
                  icon: Icons.radio_button_unchecked,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 10),
                _StatRow(
                  label: '今日の期限',
                  count: dueTodayCount,
                  icon: Icons.today_outlined,
                  color: const Color(0xFFFF9500),
                ),
                const SizedBox(height: 10),
                _StatRow(
                  label: '完了',
                  count: completedCount,
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF34C759),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;

    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.secondaryLabel,
                ),
          ),
        ),
        Text(
          '$count',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 10.0;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth);

    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);

    if (progress > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor;
  }
}
