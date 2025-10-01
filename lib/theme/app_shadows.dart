import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppShadows {
  // Light shadows
  static List<BoxShadow> light = [
    BoxShadow(
      color: AppColors.shadowLight,
      offset: const Offset(0, 2),
      blurRadius: 4,
      spreadRadius: 0,
    ),
  ];
  
  // Medium shadows
  static List<BoxShadow> medium = [
    BoxShadow(
      color: AppColors.shadowMedium,
      offset: const Offset(0, 4),
      blurRadius: 8,
      spreadRadius: 0,
    ),
  ];
  
  // Dark shadows
  static List<BoxShadow> dark = [
    BoxShadow(
      color: AppColors.shadowDark,
      offset: const Offset(0, 8),
      blurRadius: 16,
      spreadRadius: 0,
    ),
  ];
  
  // Card shadows
  static List<BoxShadow> card = [
    BoxShadow(
      color: AppColors.shadowMedium,
      offset: const Offset(0, 2),
      blurRadius: 10,
      spreadRadius: 0,
    ),
  ];
  
  // Button shadows
  static List<BoxShadow> button = [
    BoxShadow(
      color: AppColors.primary.withOpacity(0.3),
      offset: const Offset(0, 4),
      blurRadius: 8,
      spreadRadius: 0,
    ),
  ];
}
