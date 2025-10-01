import 'package:flutter/material.dart';

class AppSpacing {
  // Base spacing unit
  static const double base = 8.0;
  
  // Common spacing values
  static const double xs = base * 0.5;    // 4
  static const double sm = base;          // 8
  static const double md = base * 2;      // 16
  static const double lg = base * 3;      // 24
  static const double xl = base * 4;      // 32
  static const double xxl = base * 6;     // 48
  static const double xxxl = base * 8;    // 64
  
  // Padding utilities
  static const EdgeInsets paddingXS = EdgeInsets.all(xs);
  static const EdgeInsets paddingSM = EdgeInsets.all(sm);
  static const EdgeInsets paddingMD = EdgeInsets.all(md);
  static const EdgeInsets paddingLG = EdgeInsets.all(lg);
  static const EdgeInsets paddingXL = EdgeInsets.all(xl);
  
  // Horizontal padding
  static const EdgeInsets paddingHorizontalXS = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets paddingHorizontalSM = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets paddingHorizontalMD = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets paddingHorizontalLG = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets paddingHorizontalXL = EdgeInsets.symmetric(horizontal: xl);
  
  // Vertical padding
  static const EdgeInsets paddingVerticalXS = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets paddingVerticalSM = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets paddingVerticalMD = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets paddingVerticalLG = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets paddingVerticalXL = EdgeInsets.symmetric(vertical: xl);
}

class AppRadius {
  // Border radius values
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  
  // BorderRadius utilities
  static BorderRadius get radiusXS => BorderRadius.circular(xs);
  static BorderRadius get radiusSM => BorderRadius.circular(sm);
  static BorderRadius get radiusMD => BorderRadius.circular(md);
  static BorderRadius get radiusLG => BorderRadius.circular(lg);
  static BorderRadius get radiusXL => BorderRadius.circular(xl);
  static BorderRadius get radiusXXL => BorderRadius.circular(xxl);
  
  // Circular radius for avatars, buttons, etc.
  static BorderRadius get circle => BorderRadius.circular(100);
}
