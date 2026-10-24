import 'package:flutter/material.dart';

/// Design tokens strictly conforming to `specs/design_system.md`
/// and visual parity with the web dashboard.
class AppColors {
  AppColors._();

  // Backgrounds & Canvas
  static const Color scaffoldBackground = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderSubtle = Color(0xFFF1F5F9);
  static const Color divider = Color(0xFFE2E8F0);

  // Brand & Primary
  static const Color primaryNavy = Color(0xFF08284B); // BantayGawa Signature Navy
  static const Color primaryDark = Color(0xFF07101E);
  static const Color accentGreen = Color(0xFF167346); // LGU Environment Green
  static const Color paleGreen = Color(0xFFE8F5EE);
  static const Color accentBlue = Color(0xFF2563EB);

  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF334155);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textLight = Color(0xFF94A3B8);

  // Status & Badges
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color successText = Color(0xFF166534);

  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color warningText = Color(0xFF92400E);
  static const Color warningOrange = Color(0xFFE97800);

  static const Color dangerBg = Color(0xFFFEE2E2);
  static const Color dangerText = Color(0xFF991B1B);
  static const Color dangerRed = Color(0xFFA92025);

  static const Color neutralBg = Color(0xFFF1F5F9);
  static const Color neutralText = Color(0xFF475569);
}
