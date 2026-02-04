import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/theme.dart';
import '../providers/game_provider.dart';
import 'category_screen.dart';

class ModeScreen extends ConsumerWidget {
  const ModeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              _BackButton(onPressed: () => Navigator.pop(context)),
              const SizedBox(height: AppSpacing.xl),

              // Title
              Text(
                'Select Game Mode',
                style: AppTypography.headline3,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Description
              Text(
                'Choose how you want to play',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Mode options
              _ModeButton(
                icon: Icons.person,
                title: 'Single Player',
                subtitle: 'Play solo and beat your high score',
                isPrimary: true,
                onTap: () {
                  ref.read(selectedGameModeProvider.notifier).state =
                      GameMode.singlePlayer;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CategoryScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              _ModeButton(
                icon: Icons.people,
                title: 'Local Multiplayer',
                subtitle: 'Play with a friend on this device',
                iconBackgroundColor: const Color(0x268B5CF6),
                onTap: () {
                  ref.read(selectedGameModeProvider.notifier).state =
                      GameMode.localMultiplayer;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CategoryScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              _ModeButton(
                icon: Icons.public,
                title: 'Online Multiplayer',
                subtitle: 'Challenge players worldwide',
                iconBackgroundColor: const Color(0x2614B8A6),
                badge: _PremiumBadge(),
                onTap: () {
                  ref.read(selectedGameModeProvider.notifier).state =
                      GameMode.onlineMultiplayer;
                  // TODO: Check subscription, show paywall if needed
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CategoryScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _BackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Icon(
          Icons.arrow_back,
          size: 24,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isPrimary;
  final Color? iconBackgroundColor;
  final Widget? badge;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isPrimary = false,
    this.iconBackgroundColor,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isPrimary ? AppColors.purple : AppColors.surface;
    final textColor = isPrimary ? AppColors.white : AppColors.textPrimary;
    final subtitleColor =
        isPrimary ? AppColors.white.withValues(alpha: 0.8) : AppColors.textSecondary;
    final iconBgColor = isPrimary
        ? AppColors.white.withValues(alpha: 0.2)
        : (iconBackgroundColor ?? const Color(0x268B5CF6));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: isPrimary
              ? null
              : Border.all(
                  color: AppColors.elevated,
                  width: 1,
                ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 24,
                color: isPrimary ? AppColors.white : AppColors.purple,
              ),
            ),
            const SizedBox(width: 16),

            // Text
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyLarge.copyWith(
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),

            // Badge (if present)
            ?badge,
          ],
        ),
      ),
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x26FBBF24),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Premium',
        style: AppTypography.labelSmall.copyWith(
          color: const Color(0xFFFBBF24),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
