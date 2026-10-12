import 'package:flutter/material.dart';

/// Design tokens strictly conforming to `specs/design_system.md`
/// and extracted from the Admin prototype.
class AppColors {
  AppColors._();

  // Backgrounds & Canvas
  static const Color scaffoldBackground = Color(0xFFF8FAFC); // Cool Light Gray
  static const Color surface = Color(0xFFFFFFFF); // Pure White
  static const Color surfaceSubtle = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0); // Slate Border
  static const Color borderSubtle = Color(0xFFF1F5F9);
  static const Color divider = Color(0xFFE2E8F0);

  // Brand & Primary Controls
  static const Color primaryNavy = Color(0xFF0A194E); // Deep Midnight Navy
  static const Color primaryDark = Color(0xFF0F172A); // Slate 900
  static const Color accentBlue = Color(0xFF2563EB); // Electric Royal Blue
  static const Color accentEmerald = Color(0xFF059669); // Emerald Green
  static const Color navActiveBackground = Color(0xFFEFF6FF); // Light Tint Blue
  static const Color navActiveIndicator = Color(0xFF2563EB); // 3dp indicator border
  static const Color secondaryButton = Color(0xFFEAEEF4); // Pale Slate Gray
  static const Color secondaryButtonText = Color(0xFF334155);

  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF334155); // Slate 700
  static const Color textMuted = Color(0xFF64748B); // Slate 500
  static const Color textLight = Color(0xFF94A3B8); // Slate 400

  // Status Pills & Alert Colors
  // Optimal / Success / Active
  static const Color statusOptimalBg = Color(0xFFDBEAFE);
  static const Color statusOptimalText = Color(0xFF1E40AF);
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color successText = Color(0xFF166534);

  // Warning / Understaffed / Action Required / Danger
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color warningText = Color(0xFF92400E);
  static const Color dangerBg = Color(0xFFFEE2E2);
  static const Color dangerText = Color(0xFF991B1B);
  static const Color dangerBorder = Color(0xFFFECACA);
  static const Color brightRed = Color(0xFFDC2626);

  // Neutral / Review / Stable
  static const Color neutralBg = Color(0xFFF1F5F9);
  static const Color neutralText = Color(0xFF475569);

  // Counter Badges
  static const Color badgeBg = Color(0xFFFEE2E2);
  static const Color badgeText = Color(0xFFDC2626);
}
