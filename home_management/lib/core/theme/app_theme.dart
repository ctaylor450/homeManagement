import 'package:flutter/material.dart';

class AppTheme {
  // Colors
  static const Color primaryColor = Color(0xFF6366F1);
  static const Color secondaryColor = Color(0xFF8B5CF6);
  static const Color accentColor = Color(0xFF10B981);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color successColor = Color(0xFF10B981);
  
  static const Color backgroundColor = Color(0xFFF9FAFB);
  static const Color surfaceColor = Colors.white;
  static const Color textPrimaryColor = Color(0xFF111827);
  static const Color textSecondaryColor = Color(0xFF6B7280);
  
  // Priority Colors
  static const Color highPriorityColor = Color(0xFFEF4444);
  static const Color mediumPriorityColor = Color(0xFFF59E0B);
  static const Color lowPriorityColor = Color(0xFF10B981);
  
  // Status Colors
  static const Color publicTaskColor = Color(0xFF3B82F6);
  static const Color assignedTaskColor = Color(0xFF8B5CF6);
  static const Color claimedTaskColor = Color(0xFFF59E0B);
  static const Color completedTaskColor = Color(0xFF10B981);
  
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: textPrimaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: const CardThemeData(
        color: surfaceColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimaryColor,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textPrimaryColor,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimaryColor,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimaryColor,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: textPrimaryColor,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: textSecondaryColor,
        ),
      ),
    );
  }
  
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF111827),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1F2937),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}