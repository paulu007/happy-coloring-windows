import 'dart:ui';

class AppConstants {
  // App Info
  static const String appName = 'Happy Color';
  static const String appVersion = '1.0.0';

  // Canvas Settings
  static const double minZoom = 0.5;
  static const double maxZoom = 5.0;
  static const double defaultZoom = 1.0;

  // Animation Durations
  static const Duration fillAnimationDuration = Duration(milliseconds: 300);
  static const Duration transitionDuration = Duration(milliseconds: 200);

  // Sizes
  static const double paletteItemSize = 50.0;
  static const double strokeWidth = 0.5;
  static const double numberFontSize = 8.0;

  // Database
  static const String databaseName = 'happy_color.db';
  static const int databaseVersion = 1;
}

class AppColors {
  static const Color primary = Color(0xFF6C63FF);
  static const Color secondary = Color(0xFFFF6584);
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF2D3436);
  static const Color textSecondary = Color(0xFF636E72);
  static const Color unfilled = Color(0xFFFFFFFF);
  static const Color stroke = Color(0xFF95A5A6);
}