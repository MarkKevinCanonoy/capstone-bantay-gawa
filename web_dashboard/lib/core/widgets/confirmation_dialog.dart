import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'app_button.dart';

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final ButtonVariant confirmVariant;
  final Widget? contentWidget;
  final FutureOr<dynamic> Function()? onConfirm;
  final MainAxisAlignment actionsAlignment;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.confirmVariant = ButtonVariant.primary,
    this.contentWidget,
    this.onConfirm,
    this.actionsAlignment = MainAxisAlignment.spaceBetween,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    ButtonVariant confirmVariant = ButtonVariant.primary,
    Widget? contentWidget,
    FutureOr<dynamic> Function()? onConfirm,
    MainAxisAlignment actionsAlignment = MainAxisAlignment.spaceBetween,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        confirmVariant: confirmVariant,
        contentWidget: contentWidget,
        onConfirm: onConfirm,
        actionsAlignment: actionsAlignment,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDanger = confirmVariant == ButtonVariant.danger;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      child: Container(
        width: 560,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDanger ? AppColors.dangerBg : AppColors.navActiveBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isDanger ? Icons.delete_outline_rounded : Icons.help_outline_rounded,
                      color: isDanger ? AppColors.brightRed : AppColors.accentBlue,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 16),

              Text(
                message,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              if (contentWidget != null) ...[
                const SizedBox(height: 16),
                contentWidget!,
              ],
              const SizedBox(height: 24),

              // Side-by-side action buttons: Cancel on Left, Confirm/Delete on Right
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppButton(
                    label: cancelLabel,
                    variant: ButtonVariant.outline,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  AppButton(
                    label: confirmLabel,
                    variant: confirmVariant,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    onPressed: () async {
                      if (onConfirm != null) {
                        final result = await onConfirm!();
                        if (result == false) return;
                      }
                      if (context.mounted) {
                        Navigator.of(context).pop(true);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
