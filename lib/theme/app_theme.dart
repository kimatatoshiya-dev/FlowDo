import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Apple 純正アプリ風のライト / ダークテーマ
class AppTheme {
  AppTheme._();

  static const _iosBlue = Color(0xFF007AFF);
  static const _lightBackground = Color(0xFFF2F2F7);
  static const _darkBackground = Color(0xFF000000);
  static const _darkSurface = Color(0xFF1C1C1E);

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _iosBlue,
      brightness: Brightness.light,
      surface: Colors.white,
    );

    return _buildTheme(
      colorScheme: colorScheme,
      scaffoldBackground: _lightBackground,
      groupedSurface: Colors.white,
      completedTaskSurface: const Color(0xFFF5F5F7),
      inputAreaFill: Colors.white,
      inputAreaFillFocused: const Color(0xFFFAFCFF),
      dividerColor: const Color(0xFFE5E5EA),
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _iosBlue,
      brightness: Brightness.dark,
      surface: _darkSurface,
    );

    return _buildTheme(
      colorScheme: colorScheme,
      scaffoldBackground: _darkBackground,
      groupedSurface: _darkSurface,
      completedTaskSurface: const Color(0xFF2C2C2E),
      inputAreaFill: _darkSurface,
      inputAreaFillFocused: const Color(0xFF222226),
      dividerColor: const Color(0xFF38383A),
      systemOverlayStyle: SystemUiOverlayStyle.light,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    required Color groupedSurface,
    required Color completedTaskSurface,
    required Color inputAreaFill,
    required Color inputAreaFillFocused,
    required Color dividerColor,
    required SystemUiOverlayStyle systemOverlayStyle,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      dividerColor: dividerColor,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scaffoldBackground,
        foregroundColor: colorScheme.onSurface,
        systemOverlayStyle: systemOverlayStyle,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 34,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: groupedSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: groupedSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _iosBlue,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        iconColor: colorScheme.primary,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: BorderSide.none,
      ),
      extensions: [
        FlowDoColors(
          groupedBackground: scaffoldBackground,
          groupedSurface: groupedSurface,
          completedTaskSurface: completedTaskSurface,
          inputAreaFill: inputAreaFill,
          inputAreaFillFocused: inputAreaFillFocused,
          secondaryLabel: colorScheme.onSurface.withValues(alpha: 0.55),
          separator: dividerColor,
        ),
      ],
    );
  }
}

/// テーマ拡張（グループ化リスト用の色）
class FlowDoColors extends ThemeExtension<FlowDoColors> {
  const FlowDoColors({
    required this.groupedBackground,
    required this.groupedSurface,
    required this.completedTaskSurface,
    required this.inputAreaFill,
    required this.inputAreaFillFocused,
    required this.secondaryLabel,
    required this.separator,
  });

  final Color groupedBackground;
  final Color groupedSurface;
  final Color completedTaskSurface;
  final Color inputAreaFill;
  final Color inputAreaFillFocused;
  final Color secondaryLabel;
  final Color separator;

  @override
  FlowDoColors copyWith({
    Color? groupedBackground,
    Color? groupedSurface,
    Color? completedTaskSurface,
    Color? inputAreaFill,
    Color? inputAreaFillFocused,
    Color? secondaryLabel,
    Color? separator,
  }) {
    return FlowDoColors(
      groupedBackground: groupedBackground ?? this.groupedBackground,
      groupedSurface: groupedSurface ?? this.groupedSurface,
      completedTaskSurface:
          completedTaskSurface ?? this.completedTaskSurface,
      inputAreaFill: inputAreaFill ?? this.inputAreaFill,
      inputAreaFillFocused:
          inputAreaFillFocused ?? this.inputAreaFillFocused,
      secondaryLabel: secondaryLabel ?? this.secondaryLabel,
      separator: separator ?? this.separator,
    );
  }

  @override
  FlowDoColors lerp(ThemeExtension<FlowDoColors>? other, double t) {
    if (other is! FlowDoColors) return this;
    return FlowDoColors(
      groupedBackground:
          Color.lerp(groupedBackground, other.groupedBackground, t)!,
      groupedSurface: Color.lerp(groupedSurface, other.groupedSurface, t)!,
      completedTaskSurface:
          Color.lerp(completedTaskSurface, other.completedTaskSurface, t)!,
      inputAreaFill: Color.lerp(inputAreaFill, other.inputAreaFill, t)!,
      inputAreaFillFocused:
          Color.lerp(inputAreaFillFocused, other.inputAreaFillFocused, t)!,
      secondaryLabel: Color.lerp(secondaryLabel, other.secondaryLabel, t)!,
      separator: Color.lerp(separator, other.separator, t)!,
    );
  }
}
