import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum ButtonVariant { primary, accent, secondary, danger, outline }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonVariant variant;
  final bool isLoading;
  final double? width;
  final EdgeInsetsGeometry? padding;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = ButtonVariant.primary,
    this.isLoading = false,
    this.width,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    BorderSide? border;

    switch (variant) {
      case ButtonVariant.primary:
        bg = AppColors.primaryNavy;
        fg = Colors.white;
        break;
      case ButtonVariant.accent:
        bg = AppColors.accentBlue;
        fg = Colors.white;
        break;
      case ButtonVariant.secondary:
        bg = AppColors.secondaryButton;
        fg = AppColors.secondaryButtonText;
        break;
      case ButtonVariant.danger:
        bg = AppColors.brightRed;
        fg = Colors.white;
        break;
      case ButtonVariant.outline:
        bg = Colors.transparent;
        fg = AppColors.textSecondary;
        border = const BorderSide(color: AppColors.border);
        break;
    }

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: fg,
            ),
          ),
          const SizedBox(width: 8),
        ] else if (icon != null) ...[
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    Widget btn = Material(
      color: onPressed == null ? bg.withValues(alpha: 0.5) : bg,
      borderRadius: BorderRadius.circular(8),
      shape: border != null ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: border) : null,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: padding,
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: btn);
    }

    return btn;
  }
}
