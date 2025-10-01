import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF2F86FE);
  static const Color primaryLight = Color(0xFF5BA0FF);
  static const Color primaryDark = Color(0xFF1A6BDB);
  
  // Secondary Colors
  static const Color secondary = Color(0xFF6C7B7F);
  static const Color secondaryLight = Color(0xFF9CADB2);
  static const Color secondaryDark = Color(0xFF4A5759);
  
  // Background Colors
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFF5F7FA);
  
  // Text Colors
  static const Color textPrimary = Color(0xFF1E1E1E);
  static const Color textSecondary = Color(0xFF6C7B7F);
  static const Color textLight = Color(0xFF9CADB2);
  static const Color textWhite = Color(0xFFFFFFFF);
  
  // Accent Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);
  
  // Status Colors
  static const Color online = Color(0xFF4CAF50);
  static const Color offline = Color(0xFFBDBDBD);
  static const Color pending = Color(0xFFFF9800);
  static const Color approved = Color(0xFF4CAF50);
  static const Color rejected = Color(0xFFF44336);
  
  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2F86FE),
      Color(0xFF1A6BDB),
    ],
  );
  
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFF8F9FA),
    ],
  );
  
  // Border Colors
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color borderMedium = Color(0xFFD1D5DB);
  static const Color borderDark = Color(0xFF9CA3AF);
  
  // Shadow Colors
  static const Color shadowLight = Color(0x0A000000);
  static const Color shadowMedium = Color(0x14000000);
  static const Color shadowDark = Color(0x1F000000);
}
