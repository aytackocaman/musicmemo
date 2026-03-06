import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../l10n/app_localizations.dart';

/// Shows a styled confirmation dialog matching the app design system.
///
/// [confirmLabel] defaults to localized 'Confirm'. Set [isDestructive] to true
/// to tint the confirm button red instead of purple.
Future<void> showAppDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  bool isDestructive = false,
  bool showCancel = true,
  required VoidCallback onConfirm,
}) {
  final l10n = AppLocalizations.of(context)!;
  final resolvedConfirmLabel = confirmLabel ?? l10n.confirm;
  final resolvedCancelLabel = cancelLabel ?? l10n.cancel;

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
                if (showCancel) ...[
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
                          child: Text(resolvedCancelLabel, style: AppTypography.buttonSecondary(dialogContext)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
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
                            : dialogContext.colors.accent,
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                      child: Center(
                        child: Text(
                          resolvedConfirmLabel,
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
  bool isSuccess = false,
  Duration duration = const Duration(seconds: 2),
}) {
  final Color bgColor;
  final Color textColor;
  final IconData? icon;

  if (isError) {
    bgColor = const Color(0xFFEF4444);
    textColor = AppColors.white;
    icon = Icons.error_outline;
  } else if (isSuccess) {
    bgColor = AppColors.teal;
    textColor = AppColors.white;
    icon = Icons.check_circle_outline;
  } else {
    bgColor = context.colors.surface;
    textColor = context.colors.textPrimary;
    icon = null;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: textColor, size: 20),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySmall(context).copyWith(color: textColor),
            ),
          ),
        ],
      ),
      backgroundColor: bgColor,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: duration,
    ),
  );
}
