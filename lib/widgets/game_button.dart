import 'package:flutter/material.dart';
import '../config/theme.dart';

enum GameButtonVariant { primary, secondary, ghost }

class GameButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final GameButtonVariant variant;

  const GameButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = GameButtonVariant.primary,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = switch (variant) {
      GameButtonVariant.primary => AppColors.purple,
      GameButtonVariant.secondary => context.colors.surface,
      GameButtonVariant.ghost => Colors.transparent,
    };
    final foregroundColor = switch (variant) {
      GameButtonVariant.primary => AppColors.white,
      GameButtonVariant.secondary => context.colors.textPrimary,
      GameButtonVariant.ghost => context.colors.textSecondary,
    };

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 24),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: variant == GameButtonVariant.primary
                  ? AppTypography.button
                  : AppTypography.buttonSecondary(context).copyWith(
                      color: foregroundColor,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
