import 'package:flutter/material.dart';
import 'dart:ui' show FontFeature;  // Add this import
import 'package:google_fonts/google_fonts.dart';
import 'constants.dart';

// ... rest of the file

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(  // Use const TextStyle
          fontFamily: 'Segoe UI',  // Windows system font
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      textTheme: const TextTheme(  // Use default text theme
        displayLarge: TextStyle(fontFamily: 'Segoe UI'),
        displayMedium: TextStyle(fontFamily: 'Segoe UI'),
        displaySmall: TextStyle(fontFamily: 'Segoe UI'),
        headlineLarge: TextStyle(fontFamily: 'Segoe UI'),
        headlineMedium: TextStyle(fontFamily: 'Segoe UI'),
        headlineSmall: TextStyle(fontFamily: 'Segoe UI'),
        titleLarge: TextStyle(fontFamily: 'Segoe UI'),
        titleMedium: TextStyle(fontFamily: 'Segoe UI'),
        titleSmall: TextStyle(fontFamily: 'Segoe UI'),
        bodyLarge: TextStyle(fontFamily: 'Segoe UI'),
        bodyMedium: TextStyle(fontFamily: 'Segoe UI'),
        bodySmall: TextStyle(fontFamily: 'Segoe UI'),
        labelLarge: TextStyle(fontFamily: 'Segoe UI'),
        labelMedium: TextStyle(fontFamily: 'Segoe UI'),
        labelSmall: TextStyle(fontFamily: 'Segoe UI'),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF1A1A2E),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF16213E),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Segoe UI',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Segoe UI'),
        displayMedium: TextStyle(fontFamily: 'Segoe UI'),
        displaySmall: TextStyle(fontFamily: 'Segoe UI'),
        headlineLarge: TextStyle(fontFamily: 'Segoe UI'),
        headlineMedium: TextStyle(fontFamily: 'Segoe UI'),
        headlineSmall: TextStyle(fontFamily: 'Segoe UI'),
        titleLarge: TextStyle(fontFamily: 'Segoe UI'),
        titleMedium: TextStyle(fontFamily: 'Segoe UI'),
        titleSmall: TextStyle(fontFamily: 'Segoe UI'),
        bodyLarge: TextStyle(fontFamily: 'Segoe UI'),
        bodyMedium: TextStyle(fontFamily: 'Segoe UI'),
        bodySmall: TextStyle(fontFamily: 'Segoe UI'),
        labelLarge: TextStyle(fontFamily: 'Segoe UI'),
        labelMedium: TextStyle(fontFamily: 'Segoe UI'),
        labelSmall: TextStyle(fontFamily: 'Segoe UI'),
      ),
    );
  }
}