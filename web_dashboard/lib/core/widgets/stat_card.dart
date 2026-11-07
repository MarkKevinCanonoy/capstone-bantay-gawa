import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'app_card.dart';
import 'status_badge.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final BadgeType? badgeType;
  final String? badgeLabel;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
    this.badgeType,
    this.badgeLabel,
    this.onTap,
  });

  (Color, Color) _getAccentColors(BadgeType? type) {
    switch (type) {
      case BadgeType.optimal:
        return (const Color(0xFF059669), const Color(0xFFECFDF5));
      case BadgeType.success:
        return (AppColors.accentBlue, AppColors.navActiveBackground);
      case BadgeType.warning:
        return (const Color(0xFFD97706), const Color(0xFFFFFBEB));
      case BadgeType.danger:
        return (AppColors.brightRed, AppColors.dangerBg);
      case BadgeType.neutral:
      default:
        return (AppColors.primaryNavy, AppColors.surfaceSubtle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (accentColor, iconBg) = _getAccentColors(badgeType);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textLight,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 19, color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              if (badgeLabel != null && badgeType != null)
                StatusBadge(label: badgeLabel!, type: badgeType!),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
