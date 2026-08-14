import 'package:flutter/material.dart';

import '../../models/dashboard_weather_snapshot.dart';
import '../../theme/app_theme.dart';
import 'dashboard_surface_card.dart';

/// Dashboard 最上部の天気カード
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
    final temperatureLabel = weather.isUnavailable
        ? '--'
        : '${weather.temperatureCelsius}';

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
            '$temperatureLabel℃',
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
                if (weather.showPrecipitation) ...[
                  const SizedBox(height: 2),
                  Text(
                    '降水確率 ${weather.precipitationPercent}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.secondaryLabel,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
