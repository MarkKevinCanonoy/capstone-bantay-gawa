import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum BadgeType { optimal, warning, danger, neutral, success }

class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeType type;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    this.type = BadgeType.neutral,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;

    switch (type) {
      case BadgeType.optimal:
        bg = AppColors.statusOptimalBg;
        text = AppColors.statusOptimalText;
        break;
      case BadgeType.success:
        bg = AppColors.successBg;
        text = AppColors.successText;
        break;
      case BadgeType.warning:
        bg = AppColors.warningBg;
        text = AppColors.warningText;
        break;
      case BadgeType.danger:
        bg = AppColors.dangerBg;
        text = AppColors.dangerText;
        break;
      case BadgeType.neutral:
        bg = AppColors.neutralBg;
        text = AppColors.neutralText;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: text),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: text,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
