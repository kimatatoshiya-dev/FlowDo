import 'package:flutter/material.dart';

import '../../models/flowdo_dashboard_stats.dart';
import '../../theme/app_theme.dart';
import 'dashboard_surface_card.dart';

/// Dashboard 最上部の天気カード（将来 Weather API 差し替え用）
class DashboardWeatherCard extends StatelessWidget {
  const DashboardWeatherCard({
    super.key,
    required this.weather,
    this.onTap,
  });

  final DashboardWeatherSnapshot weather;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowDoColors>()!;

    return DashboardSurfaceCard(
      key: const ValueKey('dashboard_weather_card'),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            weather.weatherIconEmoji,
            style: const TextStyle(fontSize: 28, height: 1),
          ),
          const SizedBox(width: 12),
          Text(
            '${weather.temperatureCelsius}℃',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  weather.locationLabel,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '降水確率 ${weather.precipitationPercent}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.secondaryLabel,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
