import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Reusable BantayGawa brand logo widget.
/// Uses the official Ormoc City 1947 Seal from `web_dashboard/build/web/favicon.png`.
class AppLogo extends StatelessWidget {
  final bool compact;
  final bool isDark;
  final bool showSubtitle;
  final String? subtitle;

  const AppLogo({
    super.key,
    this.compact = false,
    this.isDark = false,
    this.showSubtitle = true,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final boxSize = compact ? 38.0 : 72.0;
    final titleSize = compact ? 16.0 : 22.0;
    final subSize = compact ? 10.0 : 12.0;

    final titleColor = isDark ? Colors.white : AppColors.primaryNavy;
    final subColor = isDark ? Colors.white70 : AppColors.textMuted;

    final logoIcon = Container(
      width: boxSize,
      height: boxSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: compact ? 4 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/logo.png',
          width: boxSize,
          height: boxSize,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: AppColors.primaryNavy,
              alignment: Alignment.center,
              child: Text(
                'BG',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 12 : 20,
                ),
              ),
            );
          },
        ),
      ),
    );

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          logoIcon,
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'BantayGawa',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                if (showSubtitle)
                  Text(
                    subtitle ?? 'ENRO Ormoc City',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: subSize,
                      color: subColor,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        logoIcon,
        const SizedBox(height: 14),
        Text(
          'BantayGawa',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.w800,
            color: titleColor,
            letterSpacing: -0.5,
          ),
        ),
        if (showSubtitle) ...[
          const SizedBox(height: 4),
          Text(
            subtitle ?? 'ENRO Ormoc City • Field Worker Portal',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: subSize,
              color: subColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
