import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../widgets/game_button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.purple,
                    borderRadius: BorderRadius.circular(AppRadius.logo),
                  ),
                  child: const Icon(
                    Icons.music_note,
                    size: 56,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Title
                Text(
                  'Music Memo',
                  style: AppTypography.headline2,
                ),
                const SizedBox(height: AppSpacing.sm),

                // Subtitle
                Text(
                  'Match the sounds to win!',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                // Buttons
                SizedBox(
                  width: 280,
                  child: Column(
                    children: [
                      GameButton(
                        label: 'Play Game',
                        icon: Icons.play_arrow,
                        onPressed: () {
                          // TODO: Navigate to game screen
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      GameButton(
                        label: 'Settings',
                        icon: Icons.settings,
                        variant: GameButtonVariant.secondary,
                        onPressed: () {
                          // TODO: Navigate to settings
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      GameButton(
                        label: 'Leaderboard',
                        icon: Icons.emoji_events,
                        variant: GameButtonVariant.secondary,
                        onPressed: () {
                          // TODO: Navigate to leaderboard
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                // High Score
                Column(
                  children: [
                    Text(
                      'High Score',
                      style: AppTypography.labelSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '2,450',
                      style: AppTypography.headline3.copyWith(
                        color: AppColors.teal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
