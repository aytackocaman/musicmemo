import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/haptic_service.dart';
import '../utils/responsive.dart';

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
      GameButtonVariant.primary => context.colors.accent,
      GameButtonVariant.secondary => context.colors.surface,
      GameButtonVariant.ghost => Colors.transparent,
    };
    final foregroundColor = switch (variant) {
      GameButtonVariant.primary => AppColors.white,
      GameButtonVariant.secondary => context.colors.textPrimary,
      GameButtonVariant.ghost => context.colors.textSecondary,
    };

    final s = Responsive.scale(context);
    return SizedBox(
      width: double.infinity,
      height: 56 * s,
      child: ElevatedButton(
        onPressed: () {
          HapticService.buttonTap();
          onPressed();
        },
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
              Icon(icon, size: 24 * s),
              SizedBox(width: 10 * s),
            ],
            Text(
              label,
              style: variant == GameButtonVariant.primary
                  ? AppTypography.button(context)
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
