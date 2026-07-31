import 'package:flutter/material.dart';

/// 星評価ベースの優先度（0 = なし、1〜5 = ★）
class TaskPriorityStars {
  TaskPriorityStars._();

  static const int none = 0;
  static const int max = 5;

  /// タップ切替順（☆なし → ★5 → ★4 → ★3 → ★2 → ★1 → ☆なし）
  static const cycleOrder = [0, 5, 4, 3, 2, 1];

  /// 優先度なしの表示ラベル
  static const noneLabel = '☆なし';

  /// 次の優先度を返す
  static int next(int current) {
    final index = cycleOrder.indexOf(current);
    if (index < 0) return cycleOrder.first;
    return cycleOrder[(index + 1) % cycleOrder.length];
  }

  /// ピッカー表示順（☆なし, ★5, ★4, ★3, ★2, ★1）
  static const pickerOrder = cycleOrder;

  /// 優先度の表示ラベル（★5 形式）
  static String label(int stars) {
    if (stars <= none) return noneLabel;
    return '★$stars';
  }

  /// 優先度チップの前景色・背景色
  static ({Color foreground, Color background}) chipColors(int stars) {
    final foreground = switch (stars) {
      5 => const Color(0xFFD92D20),
      4 => const Color(0xFFE86A00),
      3 => const Color(0xFFE6A800),
      2 => const Color(0xFF007AFF),
      1 => const Color(0xFFAEAEB2),
      _ => const Color(0xFF8E8E93),
    };
    final backgroundAlpha = switch (stars) {
      5 => 0.14,
      4 => 0.11,
      3 => 0.095,
      2 => 0.075,
      1 => 0.06,
      _ => 0.05,
    };
    return (
      foreground: foreground,
      background: _softChipBackground(foreground, backgroundAlpha),
    );
  }

  /// 背景だけ彩度を抑え、文字色はそのまま活かす
  static Color _softChipBackground(Color foreground, double alpha) {
    final hsl = HSLColor.fromColor(foreground);
    return hsl
        .withSaturation((hsl.saturation * 0.92).clamp(0.0, 1.0))
        .toColor()
        .withValues(alpha: alpha);
  }

  /// 旧 enum 名から星評価へ変換
  static int fromLegacyName(String? name) {
    return switch (name) {
      'high' => 5,
      'medium' => 3,
      'low' => 1,
      _ => none,
    };
  }
}
