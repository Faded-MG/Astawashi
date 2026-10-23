import 'package:flutter/material.dart';

/// Design tokens matching the Astawash reference design system.
abstract final class AppColors {
  // Brand colors
  static const Color primary = Color(0xFF004349);
  static const Color primaryDark = Color(0xFF003035);
  static const Color primaryLight = Color(0xFF0F5A62);
  static const Color secondary = Color(0xFF0D5C63);
  static const Color sand = Color(0xFFD4A373);
  static const Color sandLight = Color(0xFFF6EEDB);

  // Background and surface colors
  static const Color background = Color(0xFFF8FAF9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9);

  // Typography colors
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnSand = Color(0xFF3C2809);

  // Borders and dividers
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderSubtle = Color(0xFFF1F5F9);

  // Semantic status colors
  static const Color success = Color(0xFF16A34A);
  static const Color successBackground = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningBackground = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorBackground = Color(0xFFFEE2E2);

  // Chips
  static const Color chipBackground = Color(0xFFF1F5F9);
  static const Color chipSelectedBackground = Color(0xFF004349);
}
