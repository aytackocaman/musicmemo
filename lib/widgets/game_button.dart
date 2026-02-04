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
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _backgroundColor,
          foregroundColor: _foregroundColor,
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
                  : AppTypography.buttonSecondary.copyWith(
                      color: _foregroundColor,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Color get _backgroundColor {
    switch (variant) {
      case GameButtonVariant.primary:
        return AppColors.purple;
      case GameButtonVariant.secondary:
        return AppColors.surface;
      case GameButtonVariant.ghost:
        return Colors.transparent;
    }
  }

  Color get _foregroundColor {
    switch (variant) {
      case GameButtonVariant.primary:
        return AppColors.white;
      case GameButtonVariant.secondary:
        return AppColors.textPrimary;
      case GameButtonVariant.ghost:
        return AppColors.textSecondary;
    }
  }
}
