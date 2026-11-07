import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Reusable BantayGawa brand logo widget for Web Dashboard.
/// Displays the official Ormoc City Seal from `assets/images/logo.png`.
class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool isDark;
  final String? subtitle;

  const AppLogo({
    super.key,
    this.size = 72.0,
    this.showText = false,
    this.isDark = false,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final logoBadge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: AppColors.primaryNavy.withValues(alpha: 0.12),
          width: size > 48 ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
            blurRadius: size > 48 ? 10 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/logo.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryNavy,
              ),
              child: Icon(
                Icons.shield,
                color: Colors.white,
                size: size * 0.5,
              ),
            );
          },
        ),
      ),
    );

    if (!showText) {
      return logoBadge;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        logoBadge,
        const SizedBox(height: 14),
        Text(
          'BantayGawa Portal',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.primaryNavy,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle ?? 'Intelligent Workforce Verification System\nEnvironment and Natural Resources Office (ENRO)',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white70 : AppColors.textMuted,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
