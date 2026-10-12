import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum ToastType { success, error, info, warning }

class ToastNotification {
  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    Color bg;
    Color fg;
    IconData icon;

    switch (type) {
      case ToastType.success:
        bg = const Color(0xFF065F46); // Dark Emerald
        fg = Colors.white;
        icon = Icons.check_circle_outline;
        break;
      case ToastType.error:
        bg = const Color(0xFF991B1B); // Dark Red
        fg = Colors.white;
        icon = Icons.error_outline;
        break;
      case ToastType.warning:
        bg = const Color(0xFFB45309); // Amber 700
        fg = Colors.white;
        icon = Icons.warning_amber_rounded;
        break;
      case ToastType.info:
        bg = AppColors.primaryNavy;
        fg = Colors.white;
        icon = Icons.info_outline;
        break;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 24, right: 24, left: 24),
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x20000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: fg,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
