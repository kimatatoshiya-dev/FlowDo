import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'dashboard_surface_card.dart';

/// Dashboard 2列グリッド用の統計カード
class DashboardStatCard extends StatelessWidget {
  const DashboardStatCard({
    super.key,
    required this.emoji,
    required this.label,
    required this.value,
    this.onTap,
  });

  final String emoji;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;

    return DashboardSurfaceCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 18, height: 1.1),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.secondaryLabel,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
          ),
        ],
      ),
    );
  }
}
