import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color background  = Color(0xFF0A0D14);
  static const Color surface     = Color(0xFF111827);
  static const Color surface2    = Color(0xFF1C2333);
  static const Color border      = Color(0xFF2A3347);

  static const Color primary     = Color(0xFF3B82F6);
  static const Color primaryGlow = Color(0xFF60A5FA);
  static const Color primaryDark = Color(0xFF1D4ED8);

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color pending = Color(0xFFF97316);
  static const Color error   = Color(0xFFEF4444);
  static const Color blocked = Color(0xFF6B7280);

  static const Color textPrimary   = Color(0xFFF9FAFB);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted     = Color(0xFF4B5563);

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A0D14), Color(0xFF111827)],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
  );

  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0A0D14), Color(0xFF0D1525), Color(0xFF0A0D14)],
    stops: [0.0, 0.5, 1.0],
  );
}
