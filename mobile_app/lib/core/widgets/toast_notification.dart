import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ToastNotification {
  ToastNotification._();

  static void showSuccess(BuildContext context, String message) {
    _show(context, message, AppColors.successBg, AppColors.successText, Icons.check_circle_outline);
  }

  static void showError(BuildContext context, String message) {
    _show(context, message, AppColors.dangerBg, AppColors.dangerText, Icons.error_outline);
  }

  static void showWarning(BuildContext context, String message) {
    _show(context, message, AppColors.warningBg, AppColors.warningText, Icons.warning_amber_outlined);
  }

  static void showInfo(BuildContext context, String message) {
    _show(context, message, const Color(0xFFDBEAFE), const Color(0xFF1E40AF), Icons.info_outline);
  }

  static void _show(BuildContext context, String message, Color bg, Color text, IconData icon) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: bg,
        elevation: 2,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            Icon(icon, color: text, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: text, fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
