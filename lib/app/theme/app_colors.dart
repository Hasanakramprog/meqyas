import 'package:flutter/material.dart';

/// Architectural & Industrial Theme Palette for "مقياس" (Maqyas)
/// Designed around aluminum extrusion profiles, laser measurement precision,
/// and tempered glass craftsmanship. Free of generic/trendy AI templates.
abstract class AppColors {
  // Dark Palette (Primary Mode for Workshop Engineering)
  static const Color darkBackground = Color(0xFF0B0F17);
  static const Color darkSurface = Color(0xFF121926);
  static const Color darkCard = Color(0xFF1A2332);
  static const Color darkCardHover = Color(0xFF222E42);
  static const Color darkBorder = Color(0xFF263447);
  static const Color darkBorderSubtle = Color(0xFF1D2837);

  // Light Palette
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF1F5F9);
  static const Color lightCardHover = Color(0xFFE2E8F0);
  static const Color lightBorder = Color(0xFFCBD5E1);
  static const Color lightBorderSubtle = Color(0xFFE2E8F0);

  // Precision Industrial Accents (Anodized Aluminum Amber & Brass Caliper)
  static const Color amberPrimary = Color(0xFFD97706);
  static const Color amberHover = Color(0xFFB45309);
  static const Color amberLight = Color(0xFFF59E0B);
  static const Color amberSubtle = Color(0x26D97706);

  // Architectural Glass Accents (Tempered Glass Blue / Laser Cyan)
  static const Color glassBlue = Color(0xFF0284C7);
  static const Color glassBlueLight = Color(0xFF38BDF8);
  static const Color glassBlueSubtle = Color(0x260284C7);

  // Neutral Tones
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);

  // Functional Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color successSubtle = Color(0x2610B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSubtle = Color(0x26F59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color errorSubtle = Color(0x26EF4444);
  static const Color info = Color(0xFF0EA5E9);
  static const Color infoSubtle = Color(0x260EA5E9);

  // Optimization & Material Identification Colors
  static const Color profileBar = Color(0xFF3B82F6);
  static const Color remnant = Color(0xFFF59E0B);
  static const Color waste = Color(0xFFEF4444);
  static const Color glassPane = Color(0xFF06B6D4);
  static const Color screenMesh = Color(0xFF8B5CF6);
}
