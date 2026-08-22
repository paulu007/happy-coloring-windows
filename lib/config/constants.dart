import 'dart:ui';

class AppConstants {
  // App Info
  static const String appName = 'Happy Color';
  static const String appVersion = '1.1.0';

  // Canvas Settings
  static const double minZoom = 0.5;
  static const double maxZoom = 6.0;
  static const double defaultZoom = 1.0;

  // Animation Durations
  static const Duration fillAnimationDuration = Duration(milliseconds: 280);
  static const Duration transitionDuration = Duration(milliseconds: 200);

  // Sizes — tuned for desktop mouse targets (≥44dp) + touch fallback
  static const double paletteItemSize = 52.0;
  static const double strokeWidth = 0.7;
  static const double numberFontSize = 8.0;
  static const double desktopBreakpoint = 900.0;

  // Default converter options for imported photos.
  static const int importMaxColors = 16;
  static const int importMaxDimension = 520;

  // Database
  static const String databaseName = 'happy_color.db';
  static const int databaseVersion = 1;
}

class AppColors {
  static const Color primary = Color(0xFF6C63FF);
  static const Color secondary = Color(0xFFFF6584);
  static const Color background = Color(0xFFF5F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF2D3436);
  static const Color textSecondary = Color(0xFF636E72);
  static const Color unfilled = Color(0xFFFFFFFF);
  static const Color stroke = Color(0xFF9AA5B1);
  static const Color success = Color(0xFF00B894);
}