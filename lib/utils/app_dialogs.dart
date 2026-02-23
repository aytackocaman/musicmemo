import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Shows a styled confirmation dialog matching the app design system.
///
/// [confirmLabel] defaults to 'Confirm'. Set [isDestructive] to true
/// to tint the confirm button red instead of purple.
Future<void> showAppDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
  required VoidCallback onConfirm,
}) {
  return showDialog(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: dialogContext.colors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.bodyLarge(dialogContext)),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTypography.body(dialogContext).copyWith(color: dialogContext.colors.textSecondary),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                // Cancel
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(dialogContext),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: dialogContext.colors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.button),
                        border: Border.all(color: dialogContext.colors.elevated),
                      ),
                      child: Center(
                        child: Text(cancelLabel, style: AppTypography.buttonSecondary(dialogContext)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Confirm
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(dialogContext);
                      onConfirm();
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDestructive
                            ? const Color(0xFFEF4444)
                            : AppColors.purple,
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                      child: Center(
                        child: Text(
                          confirmLabel,
                          style: AppTypography.buttonSecondary(dialogContext).copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Shows a styled floating snackbar matching the app design system.
void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
  Duration duration = const Duration(seconds: 2),
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: AppTypography.bodySmall(context).copyWith(color: AppColors.white),
      ),
      backgroundColor:
          isError ? const Color(0xFFEF4444) : const Color(0xFF27272A),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: duration,
    ),
  );
}
