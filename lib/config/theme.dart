import 'package:flutter/material.dart';
import 'constants.dart';

/// Material 3 themes tuned for desktop (Windows, Linux, macOS).
///
/// No hard-coded font family is set so every platform renders with its
/// native system font (Segoe UI on Windows, Adwaita/Inter on Linux, SF Pro
/// on macOS) - both for a native look and to avoid font-fallback work.
class AppTheme {
  static ThemeData get lightTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    );
    return _baseTheme(scheme.copyWith(surface: Colors.white));
  }

  static ThemeData get darkTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    );
    return _baseTheme(scheme);
  }

  static ThemeData _baseTheme(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.brightness == Brightness.light
          ? AppColors.background
          : const Color(0xFF121228),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.brightness == Brightness.light
            ? AppColors.primary
            : const Color(0xFF1A2340),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 2,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.2,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 1.5,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: AppColors.primary.withOpacity(0.22),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            )),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
