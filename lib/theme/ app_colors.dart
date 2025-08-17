import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // === BACKGROUND GRAYS ===
  static const Color backgroundPrimary = Color(0xFFFFFFFF);    // White background
  static const Color backgroundSecondary = Color(0xFFF2F2F7);  // Card background
  static const Color backgroundTertiary = Color(0xFFE5E5EA);   // Elevated background
  static const Color backgroundQuaternary = Color(0xFFD1D1D6); // Input background

  // === TEXT COLORS ===
  static const Color textPrimary = Color(0xFF000000);      // Black text
  static const Color textSecondary = Color(0xFF3C3C43);    // Dark gray text
  static const Color textTertiary = Color(0xFF8E8E93);     // Medium gray text
  static const Color textDisabled = Color(0xFFC7C7CC);     // Disabled text

  // === ACCENT COLORS ===
  static const Color accent = Color(0xFF007AFF);           // Blue accent
  static const Color accentSecondary = Color(0xFF5856D6);  // Purple accent
  static const Color success = Color(0xFF30D158);          // Green
  static const Color warning = Color(0xFFFF9F0A);          // Orange
  static const Color error = Color(0xFFFF453A);            // Red

  // === INTERACTIVE STATES ===
  static const Color hover = Color(0xFFE5E5EA);
  static const Color pressed = Color(0xFFD1D1D6);
  static const Color selected = Color(0xFF007AFF);
  static const Color disabled = Color(0xFFF2F2F7);

  // === BORDERS & DIVIDERS ===
  static const Color border = Color(0xFFD1D1D6);
  static const Color borderLight = Color(0xFFE5E5EA);
  static const Color divider = Color(0xFFE5E5EA);

  // === OVERLAYS ===
  static const Color overlay = Color(0x80000000);          // Semi-transparent black
  static const Color overlayLight = Color(0x40000000);     // Light overlay
  static const Color overlayHeavy = Color(0xB3000000);     // Heavy overlay
}
