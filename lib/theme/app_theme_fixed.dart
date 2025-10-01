// import 'package:flutter/material.dart';
// import 'app_colors.dart';
// import 'app_text_styles.dart';

// class AppTheme {
//   static ThemeData get lightTheme {
//     return ThemeData(
//       useMaterial3: true,
//       brightness: Brightness.light,
      
//       // Color Scheme
//       colorScheme: const ColorScheme.light(
//         primary: AppColors.primary,
//         primaryContainer: AppColors.primaryLight,
//         secondary: AppColors.secondary,
//         secondaryContainer: AppColors.secondaryLight,
//         surface: AppColors.surface,
//         error: AppColors.error,
//         onPrimary: AppColors.textWhite,
//         onSecondary: AppColors.textWhite,
//         onSurface: AppColors.textPrimary,
//         onError: AppColors.textWhite,
//       ),
      
//       // App Bar Theme
//       appBarTheme: const AppBarTheme(
//         backgroundColor: AppColors.surface,
//         foregroundColor: AppColors.textPrimary,
//         elevation: 0,
//         centerTitle: true,
//         titleTextStyle: AppTextStyles.h5,
//         iconTheme: IconThemeData(
//           color: AppColors.textPrimary,
//           size: 24,
//         ),
//       ),
      
//       // Card Theme
//       cardTheme: CardTheme(
//         color: AppColors.surface,
//         elevation: 2,
//         shadowColor: AppColors.shadowMedium,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(16),
//         ),
//         margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       ),
      
//       // Elevated Button Theme
//       elevatedButtonTheme: ElevatedButtonThemeData(
//         style: ElevatedButton.styleFrom(
//           backgroundColor: AppColors.primary,
//           foregroundColor: AppColors.textWhite,
//           elevation: 2,
//           shadowColor: AppColors.shadowMedium,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(12),
//           ),
//           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//           textStyle: AppTextStyles.buttonText,
//         ),
//       ),
      
//       // Outlined Button Theme
//       outlinedButtonTheme: OutlinedButtonThemeData(
//         style: OutlinedButton.styleFrom(
//           foregroundColor: AppColors.primary,
//           side: const BorderSide(color: AppColors.primary, width: 1.5),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(12),
//           ),
//           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//           textStyle: AppTextStyles.buttonText.copyWith(color: AppColors.primary),
//         ),
//       ),
      
//       // Text Button Theme
//       textButtonTheme: TextButtonThemeData(
//         style: TextButton.styleFrom(
//           foregroundColor: AppColors.primary,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(8),
//           ),
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//           textStyle: AppTextStyles.labelLarge.copyWith(color: AppColors.primary),
//         ),
//       ),
      
//       // Input Decoration Theme
//       inputDecorationTheme: InputDecorationTheme(
//         filled: true,
//         fillColor: AppColors.cardBackground,
//         contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: const BorderSide(color: AppColors.borderLight),
//         ),
//         enabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: const BorderSide(color: AppColors.borderLight),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: const BorderSide(color: AppColors.primary, width: 2),
//         ),
//         errorBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: const BorderSide(color: AppColors.error),
//         ),
//         focusedErrorBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: const BorderSide(color: AppColors.error, width: 2),
//         ),
//         labelStyle: AppTextStyles.labelMedium,
//         hintStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.textLight),
//         errorStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
//       ),
      
//       // Bottom Navigation Bar Theme
//       bottomNavigationBarTheme: const BottomNavigationBarThemeData(
//         backgroundColor: AppColors.surface,
//         selectedItemColor: AppColors.primary,
//         unselectedItemColor: AppColors.textLight,
//         type: BottomNavigationBarType.fixed,
//         elevation: 8,
//         selectedLabelStyle: AppTextStyles.labelSmall,
//         unselectedLabelStyle: AppTextStyles.labelSmall,
//       ),
      
//       // Floating Action Button Theme
//       floatingActionButtonTheme: const FloatingActionButtonThemeData(
//         backgroundColor: AppColors.primary,
//         foregroundColor: AppColors.textWhite,
//         elevation: 6,
//         shape: CircleBorder(),
//       ),
      
//       // Icon Theme
//       iconTheme: const IconThemeData(
//         color: AppColors.textSecondary,
//         size: 24,
//       ),
      
//       // Divider Theme
//       dividerTheme: const DividerThemeData(
//         color: AppColors.borderLight,
//         thickness: 1,
//         space: 1,
//       ),
      
//       // Checkbox Theme
//       checkboxTheme: CheckboxThemeData(
//         fillColor: WidgetStateProperty.resolveWith((states) {
//           if (states.contains(WidgetState.selected)) {
//             return AppColors.primary;
//           }
//           return AppColors.borderMedium;
//         }),
//         checkColor: WidgetStateProperty.all(AppColors.textWhite),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
//       ),
      
//       // Radio Theme
//       radioTheme: RadioThemeData(
//         fillColor: WidgetStateProperty.resolveWith((states) {
//           if (states.contains(WidgetState.selected)) {
//             return AppColors.primary;
//           }
//           return AppColors.borderMedium;
//         }),
//       ),
      
//       // Switch Theme
//       switchTheme: SwitchThemeData(
//         thumbColor: WidgetStateProperty.resolveWith((states) {
//           if (states.contains(WidgetState.selected)) {
//             return AppColors.primary;
//           }
//           return AppColors.borderMedium;
//         }),
//         trackColor: WidgetStateProperty.resolveWith((states) {
//           if (states.contains(WidgetState.selected)) {
//             return AppColors.primaryLight;
//           }
//           return AppColors.borderLight;
//         }),
//       ),
      
//       // Slider Theme
//       sliderTheme: const SliderThemeData(
//         activeTrackColor: AppColors.primary,
//         inactiveTrackColor: AppColors.borderLight,
//         thumbColor: AppColors.primary,
//         overlayColor: AppColors.primaryLight,
//       ),
      
//       // Progress Indicator Theme
//       progressIndicatorTheme: const ProgressIndicatorThemeData(
//         color: AppColors.primary,
//         linearTrackColor: AppColors.borderLight,
//         circularTrackColor: AppColors.borderLight,
//       ),
      
//       // Dialog Theme
//       dialogTheme: DialogTheme(
//         backgroundColor: AppColors.surface,
//         elevation: 8,
//         shadowColor: AppColors.shadowMedium,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(16),
//         ),
//         titleTextStyle: AppTextStyles.h5,
//         contentTextStyle: AppTextStyles.bodyMedium,
//       ),
      
//       // Snack Bar Theme
//       snackBarTheme: SnackBarThemeData(
//         backgroundColor: AppColors.textPrimary,
//         contentTextStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textWhite),
//         actionTextColor: AppColors.primary,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(8),
//         ),
//         behavior: SnackBarBehavior.floating,
//         elevation: 6,
//       ),
      
//       // Chip Theme
//       chipTheme: ChipThemeData(
//         backgroundColor: AppColors.cardBackground,
//         selectedColor: AppColors.primary,
//         labelStyle: AppTextStyles.labelMedium,
//         secondaryLabelStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.textWhite),
//         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(20),
//         ),
//       ),
      
//       // Tab Bar Theme
//       tabBarTheme: const TabBarTheme(
//         labelColor: AppColors.primary,
//         unselectedLabelColor: AppColors.textLight,
//         indicatorColor: AppColors.primary,
//         labelStyle: AppTextStyles.labelLarge,
//         unselectedLabelStyle: AppTextStyles.labelLarge,
//       ),
      
//       // Text Theme
//       textTheme: const TextTheme(
//         displayLarge: AppTextStyles.h1,
//         displayMedium: AppTextStyles.h2,
//         displaySmall: AppTextStyles.h3,
//         headlineLarge: AppTextStyles.h4,
//         headlineMedium: AppTextStyles.h5,
//         headlineSmall: AppTextStyles.h6,
//         titleLarge: AppTextStyles.h5,
//         titleMedium: AppTextStyles.h6,
//         titleSmall: AppTextStyles.labelLarge,
//         bodyLarge: AppTextStyles.bodyLarge,
//         bodyMedium: AppTextStyles.bodyMedium,
//         bodySmall: AppTextStyles.bodySmall,
//         labelLarge: AppTextStyles.labelLarge,
//         labelMedium: AppTextStyles.labelMedium,
//         labelSmall: AppTextStyles.labelSmall,
//       ),
//     );
//   }
// }
